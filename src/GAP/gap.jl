# Solve generalized assignment problem with column generation
using StudentHousing, StatsBase, Distributions, JuMP, Gurobi

srand(32)
nbedrooms_range = collect(1:2)
nbedrooms_frequency = Weights([0.5, 0.5])
nbathrooms_range = collect(1:2)
nbathrooms_frequency = Weights([0.5, 0.5])
prices_range_pp = [800.0, 1000.0]
area_ranges = [0.0]
market_data = StudentHousing.MarketData(nbedrooms_range, nbedrooms_frequency,
    nbathrooms_range, nbathrooms_frequency, prices_range_pp, area_ranges)
budget = 1e6
problem_data = StudentHousingData(market_data, nhouses = 2, budget = budget, demand_distribution = Uniform())

d = problem_data

nhouses = length(d.houses)
npatterns = length(d.patterns_allow)
println(npatterns) # 13

h_init = collect(1:nhouses)
V = zeros(npatterns, nhouses)
for i = 1:nhouses
    fsb_pattern = house_allowedby(i,d)[1]
    V[fsb_pattern, i] = 1.0
end

# find one feasible assignment to house 1
# julia> house_allowedby(1,d)
# 5-element Array{Int64,1}:
#   6
#   7
#  11
#  12
#  13
# V1 = zeros(npatterns)
# V1[6] = 1.0
# we could have started with 1 column for each house consisting of zeroes
# everywhere and 1 in the first pattern allowed

# =============================================================================
# Master problem
# =============================================================================
m = Model(solver = GurobiSolver(OutputFlag=0))
@variable(m, 0 <= λ[i in h_init] <= 1)
@objective(m, Max, sum(sum(λ[i] * V[p, i] for p = 1:npatterns) for i in h_init))
@constraints(m, begin
    capsupply[p = 1:npatterns], sum(λ[i] * V[p, i] for i in h_init) <= 1
    convexity[i in h_init], sum(λ[i]) <= 1
end)

solve(m)
print(m)
println(getobjectivevalue(m))
π = getdual(m[:capsupply])
w = getdual(m[:convexity])
println("Dual vector = ", π)
println("Convexity dual = ", w)

# =============================================================================
# Sub-problems
# =============================================================================
c = ones(npatterns)

best_rc = -Inf
best_sp  = Model()
best_i = 0

# The knapsack problem for each house
function get_kp(i::Int)
    sp = Model(solver = GurobiSolver(OutputFlag=0))
    @variable(sp, v[p = 1:npatterns], Bin)
    @constraints(sp, begin
        sum(v[p] * beds_needed(p) for p = 1:npatterns) <= beds_avail(i, d.houses)
        [p = 1:npatterns], v[p] <= house_fits_pattern(i, p, d)
    end)
    @objective(sp, Max, dot((c - π), v))
    sp
end

# Get the best reduced cost over all houses
for i = 1:nhouses
    sp = get_kp(i)
    @assert solve(sp) == :Optimal
    col_rc = getobjectivevalue(sp) - w[i]
    if col_rc > best_rc
        best_rc = col_rc
        best_sp = sp
        best_i = i
    end
end

@show best_rc
@assert best_rc > 0
@show best_i
@show find(getvalue(best_sp[:v]) .> 0)
# We chose to generate a column for house 1, which accommodates students 7
# and 11

# sanity check
StudentHousing.house_allowedby(1, d)
# 5-element Array{Int64,1}:
#   6
#   7
#  11
#  12
#  13
beds_avail(i, d.houses)
# 2
beds_needed(7)
# 1.0
beds_needed(11)
# 1.0
