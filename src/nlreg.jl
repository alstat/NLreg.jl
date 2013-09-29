abstract NLregMod{T<:FP}

type NonlinearLS{T<:FP} <: StatisticalModel            # nonlinear least squares problems
    m::NLregMod{T}
    pars::Vector{T}
    incr::Vector{T}
    ch::Cholesky{T}
    rss::T      # residual sum of squares at last successful iteration
    tolsqr::T   # squared tolerance for orthogonality criterion
    minfac::T
    mxiter::Int
    fit::Bool
end
function NonlinearLS{T<:FP}(m::NLregMod{T},init::Vector{T})
    p,n = size(m); length(init) == p || error("Dimension mismatch")
    rss = updtmu!(m, init); tg = m.tgrad
    NonlinearLS(m, init, zeros(T,p), cholfact(eye(p)), rss, 1e-8, 0.5^10, 1000, false)
end
NonlinearLS{T<:FP}(m::NLregMod{T}) = NonlinearLS(m, initpars(m))

function gnfit(nl::NonlinearLS;verbose=false) # Gauss-Newton nonlinear least squares
    if !nl.fit
        m = nl.m; pars = nl.pars; incr = nl.incr; minf = nl.minfac; cvg = 2(tol = nl.tolsqr)
        r = m.resid; tg = m.tgrad; ch = nl.ch; nl.rss = rss = updtmu!(m,pars); UL = ch.UL
        for i in 1:nl.mxiter
            ## Create the Cholesky factor of tg * tg' in place
            _,info = potrf!('U',syrk!('U','N',1.,tg,0.,UL))
            info == 0 || error("Singular gradient matrix at pars = $(pars')")
            ## solve in place for the Gauss-Newton increment - done in two stages
            ## to be able to evaluate the orthogonality convergence criterion
            cvg = sqsum(trsv!('U','T','N',UL,gemv!('N',1.,tg,r,0.,incr)))/rss
            verbose && println("Iteration: ",i,", rss = ",rss,", cvg = ",cvg," at ",pars')
            trsv!('U','N','N',UL,incr)
            verbose && println("Increment: ", incr')
            f = 1.
            while true
                f >= minf || error("Failure to reduce rss at $(pars') with incr = $(incr') and minfac = $minf")
                rss = updtmu!(nl.m, pars + f * incr)
                verbose && println("  f = ",f,", rss = ",rss)
                rss < nl.rss && break
                f *= 0.5                    # step-halving
            end
            cvg < tol && break
            pars += f * incr
            nl.rss = rss
        end
        copy!(nl.pars,pars)
        cvg < tol || error("failure to converge in $(nl.mxiter) iterations")
        nl.fit = true
    end
    nl
end


function show(io::IO, nl::NonlinearLS)
    gnfit(nl)
    p,n = size(nl.m)
    s2 = nl.rss/float(n-p)
    varcov = s2 * symmetrize!(potri!('U', copy(nl.ch.UL))[1], 'U')
    stderr = sqrt(diag(varcov))
    t_vals = nl.pars./stderr
    println(io, "Model fit by nonlinear least squares to $n observations\n")
    println(io, "Parameter names:", pnames(nl.m)')
    println(io, DataFrame(parameter=nl.pars,stderr=stderr,t_value=nl.pars./stderr))
    println("Residual sum of squares at estimates = $(nl.rss)")
    println("Residual standard error = $(sqrt(s2)) on $(n-p) degrees of freedom")
end