
"""
    solve_pattern_generation(d::StudentHousingData)

Solve generalized assignment problem with column generation.
"""
function solve_pattern_generation(d::StudentHousingData)

    nhouses = length(d.houses)
    npatterns = length(d.patterns_allow)

    h_init = collect(1:nhouses)
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
    @variable(m, 0 <= λ[i in h_init] <= 1)
    @objective(m, Max, sum(λ[i] * dot(c, V[:, i]) for i in h_init))
    @constraints(m, begin
        capsupply[p = 1:npatterns], sum(λ[i] * V[p, i] for i in h_init) <= 1
        convexity[i in h_init], sum(λ[i]) <= 1
    end)

    # =========================================================================
    # The knapsack subproblem for each house
    # =========================================================================
    function get_kp(i::Int, π::Vector{Float64})
        sp = Model(solver = GurobiSolver(OutputFlag=0))
        @variable(sp, v[p = 1:npatterns], Bin)
        @constraints(sp, begin
            sum(v[p] * beds_needed(p) for p = 1:npatterns) <= beds_avail(i, d.houses)
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

        # Solve a subproblem for each house, get the column with the best reduced
        # cost over all houses
        best_rc = -Inf
        for i = 1:nhouses
            sp = get_kp(i, π)
            @assert solve(sp) == :Optimal
            col_rc = getobjectivevalue(sp) - w[i]
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
                inconstraints = [capsupply; convexity[best_i]],
                coefficients = [best_v; 1.0]
              )
        )
        iter += 1
    end

    # Return the master problem and information about generated columns
    m, V_generated, λ_generated, house_choice
end
