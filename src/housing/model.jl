# ==============================================================================
# Some helper functions

# Don't need to write this explictly but we'll do it anyway
string2vector(s::String) = parse.(split(s, ""))
# The i^th possible pattern, if there are 2^C of them in total
explicit_pattern(i::Int, c::Int) = string2vector(bin(i-1, c))
beds_avail(i::Int, houses::Vector{House}) = houses[i].nbedrooms
maintenance(i::Int, houses::Vector{House}) = maintenance(houses[i])
get_ncharacteristics(d::StudentHousingData) = length(d.all_characteristics)
get_npatterns(d::StudentHousingData) = 2^get_ncharacteristics(d)

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

    demand = round.(rand(npatterns) * 1) # move this to data part

    println(houses)
    # println(demand)

    m = Model(solver = GurobiSolver(OutputFlag=0))
    # m = Model(solver = CplexSolver(CPX_PARAM_SCRIND = 0, CPX_PARAM_MIPDISPLAY=0))
    @variables(m, begin
        shortage[1:npatterns] >= 0
        investment[1:nhouses], Bin
        assignment[1:nhouses, 1:npatterns] >= 0, Int
    end)

    @constraints(m, begin
        [p = 1:npatterns], shortage[p] == demand[p] - sum(assignment[i, p] for i = 1:nhouses)
        [i = 1:nhouses, p = 1:npatterns], assignment[i, p] * beds_needed(p) <= house_fits_pattern(i, p, d) * investment[i] * beds_avail(i, houses)
        [i = 1:nhouses], sum(assignment[i, p] * beds_needed(p) for  p = 1:npatterns) <= investment[i] * beds_avail(i, houses)
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

    nstages = 2

    npatterns = get_npatterns(d)
    houses = d.houses
    nhouses = length(d.houses)

    # This will move into the data part. Make random demand.
    nnoises = 10
    demands = Array{Float64,3}(npatterns, nnoises, nstages)
    for n in 1:nnoises
        demands[:, n, :] .= round.(rand(npatterns, nstages) * 500)
    end
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
            for p = 1:npatterns # TODO better warning than JuMP's modifying range constraints unsupported
                @rhsnoise(sp, D = demands[p, :, stage],
                    shortage[p] + sum(assignment[i, p] for i = 1:nhouses) <= D)
                @rhsnoise(sp, D = demands[p, :, stage],
                    shortage[p] + sum(assignment[i, p] for i = 1:nhouses) >= D)
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
