"""
    house_fits_pattern(i::Int, p::Int, d::StudentHousingData)

Returns a Boolean denoting whether someone with preference pattern `p` would
be willing to live in the `i`^th house.
"""
function house_fits_pattern(i::Int, p::Int, d::StudentHousingData)
    h = d.houses[i]
    for c in d.patterns_allow[p]
        if house_fits_characteristic(h, d.all_characteristics[c], d.market_data)
            return true
        end
    end
    false
end

function house_allowedby(i::Int, d::StudentHousingData)
    ret = Int[]
    for p = 1:length(d.patterns_allow)
      if house_fits_pattern(i, p, d)
          push!(ret, p)
      end
    end
    ret
end

# ==============================================================================
# One stage

function onestagemodel(d::StudentHousingData)

    houses = d.houses
    nhouses = length(d.houses)
    # One stage and deterministic
    demand = d.demands[:, 1, 1]

    # The number of only legal patterns
    npatterns = length(d.patterns_allow)

    m = Model(solver = GurobiSolver(OutputFlag=0))
    # m = Model(solver = CplexSolver(CPX_PARAM_SCRIND = 0, CPX_PARAM_MIPDISPLAY=0))
    @variables(m, begin
        shortage[1:npatterns] >= 0
        investment[1:nhouses], Bin
        assignment[i=1:nhouses, p=house_allowedby(i,d)] >= 0, Int
    end)

    @constraints(m, begin
        [p = 1:npatterns], shortage[p] == demand[p] - sum(assignment[i, p] for i = 1:nhouses if house_fits_pattern(i, p, d))
        [i = 1:nhouses], sum(beds_needed(p, d) * assignment[i, p] for p = 1:npatterns if house_fits_pattern(i, p, d)) <= investment[i] * beds_avail(i, houses)
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

    # The number of only legal patterns
    npatterns = length(d.patterns_allow)

    m = SDDPModel(stages = d.nstages,
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
            @constraint(sp, [p = 1:npatterns], shortage[p] + sum(house_fits_pattern(i, p, d) * assignment[i, p] for i = 1:nhouses) <= demands[p, 1, 1])
        else
            for p = 1:npatterns
                @rhsnoise(sp, D = demands[p, :, stage],
                    shortage[p] + sum(house_fits_pattern(i, p, d) * assignment[i, p] for i = 1:nhouses) == D)
            end
        end

        @constraints(sp, begin
            # Can't uninvest
            investment0 .<= investment
            # Only legal assignments
            [i = 1:nhouses], sum(house_fits_pattern(i, p, d) * assignment[i, p] * beds_needed(p, d) for  p = 1:npatterns) <= investment[i] * beds_avail(i, houses)
            # Budget constraint
            sum(investment[i] * maintenance(i, houses) for i = 1:nhouses) <= d.budget
        end)

        # Minimize all unmet demand
        @stageobjective(sp, sum(shortage))

        setSDDiPsolver!(sp, method=KelleyMethod(), pattern = Pattern(benders = 0, lagrangian=1))
    end
    m

end
