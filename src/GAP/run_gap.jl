using StudentHousing, StatsBase, Distributions, JuMP, Gurobi

srand(32)

# =============================================================================
# Data
# =============================================================================
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

# =============================================================================
# Solve problem
# =============================================================================
m, V_generated, λ_generated, house_choice = solve_column_generation(d)


# =============================================================================
# Look at solution
# =============================================================================
getobjectivevalue(m)

# If not integer...
for i = 1:nhouses
    setcategory(m[:λ][i], :Bin)
end
for λnew in λ_generated
    setcategory(λnew, :Bin)
end
solve(m)
getobjectivevalue(m)

# Recover the solution

# In case one of our initial columns was in the optimal basis
results = zeros(nhouses, length(d.patterns_allow))
for k = 1:nhouses
    if getvalue(m[:λ][k]) ≈ 1.0
        results[k, StudentHousing.house_allowedby(k, d)[1]] = 1.0
    end
end
# Check all the other columns we added
for k = 1:length(V_generated)
    if getvalue(λ_generated[k]) ≈ 1.0
        # Find the assignment that we picked for our house
        patterns = find(V_generated[k] .≈ 1.0)
        # Check the house index
        h = house_choice[k]
        # Mark the assignment
        results[h, patterns] .= 1.0
    end
end

println("House 1 assigned to:", find(results[1,:] .≈ 1.0))
# House 1 assigned to:[7, 11]

# sanity check
StudentHousing.house_allowedby(1, d)
# 5-element Array{Int64,1}:
#   6
#   7
#  11
#  12
#  13

println("House 2 assigned to:", find(results[2,:] .≈ 1.0))
# House 2 assigned to:[3]
# sanity check
StudentHousing.house_allowedby(2, d)
# 11-element Array{Int64,1}:
#   3
#   4
#   5
#   6
#   7
#   8
#   9
#  10
#  11
#  12
#  13
