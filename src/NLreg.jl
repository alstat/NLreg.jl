module NLreg

    using DataArrays, DataFrames, NumericExtensions, NLopt, Base.Grisu
    using Base.LinAlg.CHOLMOD: CholmodSparse!, CholmodSparse, CholmodFactor
    using StatsBase: StatisticalModel, RegressionModel
    using Distributions: FDist, ccdf
    using Base.Grisu: _show, PRECISION, FIXED, SHORTEST
    using Base.LinAlg.QRCompactWY

    importall Base
    import Distributions: fit
    import StatsBase: coef, coeftable, confint, deviance, loglikelihood, nobs, stderr, vcov,
                  model_response, predict, residuals, rle

    export     # Partially linear models
        AsympOff,     # Asymptotic regression expressed as an offset
        AsympOrig,    # Asymptotic regression through origin
        AsympReg,     # Asymptotic regression model
        Biexp,        # Bi-exponential model
        Chwirut,      # Model used in the NIST nonlinear regression examples
        Gompertz,     # Gompertz growth model
        LogBolusSD1,  # 1-compartment, single bolus dose model
        Logis3P,      # 3-parameter logistic
        Logis4P,      # 4-parameter logistic
        MicMen,       # Michaelis-Menten model
              # types for models functions and model fits
        CompositeModF,   # Nonlinear regression model function with parameter transformation
        CompositePLModF, # Partially linear regression model function with parameter trans
        NLregModF,       # Nonlinear regression model function
        NonlinearLS,     # Nonlinear least squares model
        PLinearLS,       # Partially linear regression model
        PLregModF,       # Partially linear regression model function
        NLMM,            # Nonlinear mixed-effects model
        SimpleNLMM,      # Simple population nonlinear mixed-effects model
              # parameter transformations
        Dtrans,          # diagonal parameter transformation
        ExpTr,           # scalar exponential transformation
        IdTr,            # scalar identity transformation
        Ptrans,          # abstract parameter transformation
        Strans,          # scalar parameter transformation
              # Full, nonlinear regression models
        Logsd1,       # 1-compartment, single bolus dose model with logged parameters

        fit,          # fit the model
        incr!,        # increment the spherical random effects
        initpars,     # create initial values for the parameters
        lowerbd,      # lower bounds on NLMM parameters
        npars,        # total number of parameters in an NLregMod
        pnames,       # names of parameters in a model
        pnls!,        # penalized nonlinear least squares fit
        prss!,        # penalized rss for b = lambda * (u + fac*delu)
        setpars!,     # set new parameter values (beta + theta) in an NLMM
        theta,        # extract covariance parameters
        theta!,       # set covariance parameters
        updtMM!,      # update the model matrix in a PLregMod
        updtL!,       # update L and solve for delu
        updtmu!       # update mu and tgrad

    typealias FP FloatingPoint

    type CoefTable
        df::DataFrame
        nms::Vector
        pvalcol::Integer
        function CoefTable(df::DataFrame,nms::Vector,pvalcol::Int=0)
            nr,nc = size(df)
            cnms = names(df)
            nnms = length(nms)
            0 <= pvalcol <= nc || error("pvalcol = $pvalcol should be in [0,$nc]")
            nnms == 0 || nnms == nr || error("nms should have length 0 or $nr")
            new(df,nms,pvalcol)
        end
    end

    function format_pvc(pv::Number)
        0. <= pv <= 1. || error("p-values must be in [0.,1.]")
        pv >= eps() || return "< eps()"
        (expo = ifloor(log10(pv))) >= -3 && return sprint(_show,pv,FIXED,4,true)
        sprint(_show,pv,PRECISION,2,true)
    end

    function show(io::IO, ct::CoefTable)
        df = ct.df; nr,nc = size(df); rownms = ct.nms; pvc = ct.pvalcol
        if length(rownms) == 0
            rownms = [lpad("[$i]",ifloor(log10(nr))+3)::String for i in 1:nr]
        end
        rnwidth = max(4,maximum([length(nm) for nm in rownms]) + 1)
        rownms = [rpad(nm,rnwidth) for nm in rownms]
        colnms = names(df)
        widths = [length(cn)::Int for cn in colnms]
        str = [sprint(showcompact,df[i,j]) for i in 1:nr, j in 1:nc]
        if pvc != 0                         # format the p-values column
            for i in 1:nr
                str[i,pvc] = format_pvc(df[i,pvc])
            end
        end
        for j in 1:nc
            for i in 1:nr
                lij = length(str[i,j])
                if lij > widths[j]
                    widths[j] = lij
                end
            end
        end
        widths += 1
        println(io," " ^ rnwidth *
            join([lpad(string(colnms[i]), widths[i]) for i = 1:nc], ""))
        for i = 1:nr
            print(io, rownms[i])
            for j in 1:nc
                print(io, lpad(str[i,j],widths[j]))
            end
            println(io)
        end
    end

    include("nonlinreg.jl")
    include("plreg.jl")
    include("models.jl")
    include("nlmm.jl")
    include("simplenlmm.jl")
    include("ptrans.jl")
    include("compositemodel.jl")

end # module
