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

# =============================================================================
# Compare with previous MIP results for medium problems
# =============================================================================
# Run a sanity check by solving the GAP with Gurobi
# This is different to just setting a very big budget and demand=0 in the other
# model because of the way we defined shortage to be nonnegative.

function bedrooms_scale(i::Int)
    # Number of possible bedrooms = 1 -> i
    nbedrooms_range = collect(1:i)
    # Some synthetic sampling probabilities
    weights = 2.0.^(-collect(1:i))
    weights[1] = 1 - sum(weights[2:end])
    nbedrooms_frequency = Weights(weights)
    # Return the bedroom data
    nbedrooms_range, nbedrooms_frequency
end

srand(1) # houses constructed randomly
nbathrooms_range = collect(1:3)
nbathrooms_frequency = Weights([0.5; 0.4; 0.1])
prices_range_pp = [800.0, 1000.0]
area_ranges = [0.0, 700.0, 850.0]
budget = 1000.0

for i = 1:2
    nbedrooms_range, nbedrooms_frequency = bedrooms_scale(i)
    @time market_data = StudentHousing.MarketData(nbedrooms_range,
        nbedrooms_frequency, nbathrooms_range, nbathrooms_frequency,
        prices_range_pp, area_ranges)
    @time problem_data = StudentHousingData(market_data, nhouses = 50, budget = budget,
        demand_distribution = Uniform(0.0, 100.0))
    P = StudentHousing.get_npatterns(problem_data)
    println("Using $P patterns, solving MIP:")
    tic()
    m_master, V_generated, λ_generated, house_choice = solve_column_generation(problem_data)
    toc()
    println("CG objective = ", getobjectivevalue(m_master))
end

# This represents a solution to GAP with no budget constraints, i.e. can invest
# in as many houses as we like and try to assign as many people as we can

# House 1 assigned to:[7, 11]
# House 2 assigned to:[3]
#   0.000015 seconds (1 allocation: 64 bytes)
#   0.000225 seconds (327 allocations: 319.641 KiB)

# Using 9 patterns, solving MIP:
# 0.000004 seconds (1 allocation: 64 bytes)
# 0.000132 seconds (327 allocations: 319.641 KiB)
# Using 9 patterns, solving MIP:
# elapsed time: 1.867214478 seconds
# CG objective = 4.0
# 0.000003 seconds (1 allocation: 64 bytes)
# 1.012688 seconds (1.05 M allocations: 1.084 GiB, 26.25% gc time)
# Using 329 patterns, solving MIP:
# elapsed time: 102.900935712 seconds
# CG objective = 40.0

# Sanity check, solve original problem with very large budget and demand=1
srand(1)
nbathrooms_range = collect(1:3)
nbathrooms_frequency = Weights([0.5; 0.4; 0.1])
prices_range_pp = [800.0, 1000.0]
area_ranges = [0.0, 700.0, 850.0]
budget = 5e8

for i = 1:2
    nbedrooms_range, nbedrooms_frequency = bedrooms_scale(i)
    @time market_data = StudentHousing.MarketData(nbedrooms_range,
        nbedrooms_frequency, nbathrooms_range, nbathrooms_frequency,
        prices_range_pp, area_ranges)
    @time problem_data = StudentHousingData(market_data, nhouses = 50, budget = budget,
        demand_distribution = Uniform(0.0, 0.1))
    P = StudentHousing.get_npatterns(problem_data)
    println("Using $P patterns, solving MIP:")
    @time gap_model = StudentHousing.gap_model(problem_data)
    tic()
    @assert solve(gap_model) == :Optimal
    toc()
    println("MIP objective = ", getobjectivevalue(gap_model))
end

# Using 9 patterns, solving MIP:
#   0.000535 seconds (3.66 k allocations: 209.766 KiB)
#   0.000484 seconds (6.19 k allocations: 368.250 KiB)
# elapsed time: 0.005137502 seconds
# MIP objective = 4.0
#   0.000004 seconds (1 allocation: 64 bytes)
#   0.938846 seconds (1.05 M allocations: 1.084 GiB, 27.23% gc time)
# Using 329 patterns, solving MIP:
#   0.016782 seconds (72.50 k allocations: 3.942 MiB, 33.63% gc time)
#   0.015228 seconds (234.89 k allocations: 14.217 MiB)
# elapsed time: 0.087777319 seconds
# MIP objective = 40.0
