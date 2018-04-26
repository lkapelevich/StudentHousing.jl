

"""
    house_fits_pattern(house::House, p::Int, C::Int)

Returns a Boolean denoting whether someone with preference pattern `p` would
be willing to live in `house`. `C` is the number of distinct characteristics in
our data.
"""
function house_fits_pattern(i::Int, p::Int, d::StudentHousingData)
    C = get_ncharacteristics(d)
    # The house we are concerened with
    h = d.houses[i]
    # Get the explicit pattern
    pattern = explicit_pattern(p, C)
    # For every characteristic possible
    for (i, c) in enumerate(pattern)
        # Does this person's preference pattern allow this characteristic?
        c == 0 && continue
        # Check if the house fits the characteristic also
        house_fits_characteristic(h, d.all_characteristics[i], d.market_data) && return true
    end
    false
end
beds_needed(p::Int) = 1.0

# ==============================================================================
# One stage, small version model

function onestagemodel(d::StudentHousingData)

    npatterns = get_npatterns(d)
    houses = d.houses
    nhouses = length(d.houses)
    demand = d.demands[:, 1, 1]

    # Compute the set of only legal patterns
    legal_pattern_indices = pattern_is_legal(collect(1:npatterns), d.all_characteristics)
    patterns = collect(1:npatterns)[legal_pattern_indices]
    patterns = collect(1:npatterns)

    m = Model(solver = GurobiSolver(OutputFlag=0))
    # m = Model(solver = CplexSolver(CPX_PARAM_SCRIND = 0, CPX_PARAM_MIPDISPLAY=0))
    @variables(m, begin
        shortage[patterns] >= 0
        investment[1:nhouses], Bin
        assignment[1:nhouses, patterns] >= 0, Int
    end)

    @constraints(m, begin
        [p in patterns], shortage[p] == demand[p] - sum(assignment[i, p] for i = 1:nhouses)
        [i = 1:nhouses, p in patterns], assignment[i, p] * beds_needed(p) <= house_fits_pattern(i, p, d) * investment[i] * beds_avail(i, houses)
        [i = 1:nhouses], sum(assignment[i, p] * beds_needed(p) for p in patterns) <= investment[i] * beds_avail(i, houses)
        sum(investment[i] * maintenance(i, houses) for i = 1:nhouses) <= d.budget
    end)

    @objective(m, Min, sum(shortage))
    m
end

# ==============================================================================
# Two-stage with maybe some BDD cuts for fun.

# ==============================================================================
# Multistage work in progress
function multistagemodel(d::StudentHousingData)

    houses = d.houses
    nhouses = length(d.houses)
    demands = d.demands
    upperbound = sum(sum(sum(demands)))

    m = SDDPModel(stages = nstages,
            objective_bound = 0.0,
            sense=:Min,
            solver = GurobiSolver(OutputFlag=0)) do sp, stage

        @binarystate(sp, 0 <= investment[1:nhouses] <= 1,
                investment0 == 0, Bin)

        @variables(sp, begin
            shortage[1:npatterns] >= 0
            assignment[1:nhouses, 1:npatterns] >= 0, Int
        end)

        if stage == 1
            @constraint(sp, [p = 1:npatterns], shortage[p] + sum(assignment[i, p] for i = 1:nhouses) <= demands[p, 1, 1])
        else
            for p = 1:npatterns
                @rhsnoise(sp, D = demands[p, :, stage],
                    shortage[p] + sum(assignment[i, p] for i = 1:nhouses) == D)
            end
        end

        @constraints(sp, begin
            # Can't uninvest
            investment0 .<= investment
            # Only legal assignments
            [i = 1:nhouses, p = 1:npatterns], assignment[i, p] * beds_needed(p) <= house_fits_pattern(i, p, d) * investment[i] * beds_avail(i, houses)
            [i = 1:nhouses], sum(assignment[i, p] * beds_needed(p) for  p = 1:npatterns) <= investment[i] * beds_avail(i, houses)
            # Budget constraint
            sum(investment[i] * maintenance(i, houses) for i = 1:nhouses) <= d.budget
        end)

        # Minimize all unmet demand
        @stageobjective(sp, sum(shortage))

        setSDDiPsolver!(sp, method=SubgradientMethod(upperbound))
    end
    m

end
