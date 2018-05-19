"""
    solve_ia_p_generation(d::StudentHousingData, suboptimal_rc::Bool=false)

Solve generalized assignment problem with column generation.
If `suboptimal_rc` is true, we generate the first column we find with negative
reduced cost.
"""
function solve_ia_p_generation(d::StudentHousingData, suboptimal_rc::Bool=false)

    nhouses = length(d.houses)
    npatterns = length(d.patterns_allow)

    p_init = collect(1:npatterns)
    # Create an initial set of columns by randomly picking the first entity
    # allowed for any house
    U = zeros(nhouses, npatterns)
    for p = 1:npatterns
        # If there is a pattern that doesn't match any houses, skip it
        if isempty(d.patterns_allow[p]) || (d.demands[p, 1, 1] == 0)
            continue
        end
        # A naive initial assignment
        # Find the first house allowed
        for i = 1:nhouses
            if house_fits_pattern(i, p, d)
                U[i, p] = 1.0
                break
            end
            # If we don't want to check all patterns, only add 1 col
            if suboptimal_rc
                break
            end
        end
    end

    # Our cost vector
    c = ones(nhouses)

    # =========================================================================
    # Master problem
    # =========================================================================
    m = Model(solver = GurobiSolver(OutputFlag=0))
    @variables(m, begin
        0 <= λ[i in p_init] <= 1
        0 <= invest[1:nhouses] <= 1
    end)
    @objective(m, Max, sum(λ[p] * dot(c, U[:, p]) for p in p_init))
    @constraints(m, begin
        beds[i = 1:nhouses], sum(λ[p] * U[i, p] * beds_needed(p, d) for p in p_init) <= beds_avail(i, d.houses)
        convexity[p in p_init], sum(λ[p]) <= 1
        ifinvested[i = 1:nhouses], sum(U[i, p] * λ[p] for p in p_init) <= invest[i] * beds_avail(i, d.houses)
        budget, sum(invest[i] * maintenance(i, d.houses) for i = 1:nhouses) <= d.budget
    end)

    # =========================================================================
    # The knapsack subproblem for each pattern
    # =========================================================================
    function get_kp(p::Int, π::Vector{Float64}, ρ::Vector{Float64})
        sp = Model(solver = GurobiSolver(OutputFlag=0))
        @variable(sp, u[i = 1:nhouses] >= 0, Int)
        @constraints(sp, begin
            sum(u[i] for i = 1:nhouses) <= d.demands[p, 1, 1]
            [i = 1:nhouses], u[i] <= house_fits_pattern(i, p, d)
        end)
        @objective(sp, Max, dot((c - π * beds_needed(p, d)), u) - dot(ρ, u))
        sp
    end

    # Cache information about columns we generate
    U_generated = Vector{Float64}[]
    pattern_choice = Int[]
    λ_generated = Variable[]

    best_sp  = Model()
    best_p = 0
    best_rc = Inf
    iter = 1

    while best_rc > 0
        # Solve the restricted master problem
        @assert solve(m) == :Optimal
        π = getdual(m[:beds])
        w = getdual(m[:convexity])
        ρ = getdual(m[:ifinvested])

        # Solve a subproblem for each pattern, get the column with the best reduced
        # cost over all patterns
        best_rc = -Inf
        for p = 1:npatterns
            # Get the subproblem
            sp = get_kp(p, π, ρ)
            @assert solve(sp) == :Optimal
            col_rc = getobjectivevalue(sp) - w[p]
            if col_rc > best_rc
                best_rc = col_rc
                best_sp = sp
                best_p = p
            end
            # If we don't care about the optimal column
            if suboptimal_rc
                # ... and we found one with positive reduced cost
                if col_rc > 1e-4
                    # just add the one we found
                    break
                end
            end
        end

        best_u = getvalue(best_sp[:u])
        push!(U_generated, best_u)
        push!(pattern_choice, best_p)

        # Add the best column
        push!(λ_generated, @variable(m,
                lowerbound = 0.0,
                upperbound = 1.0,
                basename="_λnew_$iter",
                objective = dot(c, best_u),
                inconstraints = [beds; convexity[best_p]; ifinvested],
                coefficients = [best_u * beds_needed(best_p, d); 1.0; best_u]
              )
        )
        iter += 1
    end
    # Solve one last time
    @assert solve(m) == :Optimal

    # Return the master problem and information about generated columns
    m, U_generated, λ_generated, pattern_choice
end
