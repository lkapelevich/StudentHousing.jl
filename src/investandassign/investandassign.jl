"""
    ia_model(d::StudentHousingData)

For debugging purposes get ia model without column generation framework.
"""
function ia_model(d::StudentHousingData)
    nhouses = length(d.houses)
    npatterns = length(d.patterns_allow)
    m = Model(solver = GurobiSolver(OutputFlag=0))
    @variables(m, begin
        assignment[1:nhouses, 1:npatterns] >= 0, Int
        invest[1:nhouses]
    end)
    @constraints(m, begin
        [i = 1:nhouses], sum(assignment[i, p] * beds_needed(p, d) for p = 1:npatterns) <= beds_avail(i, d.houses) * invest[i]
        [p = 1:npatterns], sum(assignment[:, p]) <= d.demands[p, 1, 1]
        [i = 1:nhouses, p = 1:npatterns], assignment[i, p] <= house_fits_pattern(i, p, d)
        sum(invest[i] * maintenance(i, d.houses) for i = 1:nhouses) <= d.budget
    end)
    @objective(m, Max, sum(sum(assignment)))
    m
end

"""
    solve_ia_generation(d::StudentHousingData)

Solve problem of just investing and assigning with column generation.
"""
function solve_ia_generation(d::StudentHousingData)

    nhouses = length(d.houses)
    npatterns = length(d.patterns_allow)

    # Create an initial set of columns by randomly picking the first entity
    # allowed for any house
    V = zeros(npatterns, nhouses)
    for i = 1:nhouses
        # If there is a house that doesn't match any characteristics, skip it
        if isempty(house_allowedby(i,d))
            continue
        end
        fsb_pattern = house_allowedby(i,d)[1]
        V[fsb_pattern, i] = 1.0
    end

    # Our cost vector
    c = ones(npatterns)

    # =========================================================================
    # Master problem
    # =========================================================================
    m = Model(solver = GurobiSolver(OutputFlag=0))
    @variables(m, begin
        0 <= λ[1:nhouses] <= 1
        0 <= invest[1:nhouses] <= 1
    end)
    @objective(m, Max, sum(λ[i] * dot(c, V[:, i]) for i in 1:nhouses))
    @constraints(m, begin
        capsupply[p = 1:npatterns], sum(λ[i] * V[p, i] for i in 1:nhouses) <= d.demands[p, 1, 1]
        convexity[i = 1:nhouses], sum(λ[i]) <= 1
        ifinvested[i = 1:nhouses], λ[i] <= invest[i] # V is optional
        budget, sum(invest[i] * maintenance(i, d.houses) for i = 1:nhouses) <= d.budget
    end)

    # =========================================================================
    # The knapsack subproblem for each house
    # =========================================================================
    function get_kp(i::Int, π::Vector{Float64})
        sp = Model(solver = GurobiSolver(OutputFlag=0))
        @variable(sp, v[p = 1:npatterns] >= 0, Int)
        @constraints(sp, begin
            sum(v[p] * beds_needed(p, d) for p = 1:npatterns) <= beds_avail(i, d.houses)
            [p = 1:npatterns], v[p] <= house_fits_pattern(i, p, d)
        end)
        @objective(sp, Max, dot((c - π), v))
        sp
    end

    # Cache information about columns we generate
    V_generated = Vector{Float64}[]
    house_choice = Int[]
    λ_generated = Variable[]

    best_sp  = Model()
    best_i = 0
    best_rc = Inf
    iter = 1

    while best_rc > 0
        # Solve the restricted master problem
        solve(m)
        π = getdual(m[:capsupply])
        w = getdual(m[:convexity])
        ρ = getdual(m[:ifinvested])

        # Solve a subproblem for each house, get the column with the best reduced
        # cost over all houses
        best_rc = -Inf
        for i = 1:nhouses
            sp = get_kp(i, π)
            @assert solve(sp) == :Optimal
            col_rc = getobjectivevalue(sp) - w[i] - ρ[i]
            if col_rc > best_rc
                best_rc = col_rc
                best_sp = sp
                best_i = i
            end
        end

        best_v = getvalue(best_sp[:v])
        push!(V_generated, best_v)
        push!(house_choice, best_i)

        # Add the best column
        push!(λ_generated, @variable(m,
                lowerbound = 0.0,
                upperbound = 1.0,
                basename="_λnew_$iter",
                objective = dot(c, best_v),
                inconstraints = [capsupply; convexity[best_i]; ifinvested[best_i]],
                coefficients = [best_v; 1.0; 1.0]
              )
        )
        iter += 1
    end

    # Return the master problem and information about generated columns
    m, V_generated, λ_generated, house_choice
end
