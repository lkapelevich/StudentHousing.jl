using StudentHousing, JuMP, SDDP, SDDiP, StatsBase, Distributions

srand(32)

# ==============================================================================
# One stage, demo model.
# ==============================================================================

# Since we don't have real data, we'll generate some synthetic houses.

# Express the universe of all houses we can choose from, to make synthetic data:

# Number of bedrooms
nbedrooms_range = collect(1:2)
nbedrooms_frequency = Weights([0.5, 0.5])
# Number of bathrooms
nbathrooms_range = collect(1:2)
nbathrooms_frequency = Weights([0.5, 0.5])
# The price is at most...
prices_range_pp = [800.0, 1000.0]
# The area is at least ...
area_ranges = [0.0]
# Cache the data
market_data = StudentHousing.MarketData(nbedrooms_range, nbedrooms_frequency,
    nbathrooms_range, nbathrooms_frequency, prices_range_pp, area_ranges)

# The budget we have this period:
budget = 1e6

# Generate a structure holding all of our problem data:
problem_data = StudentHousingData(market_data, nhouses = 2, budget = budget, demand_distribution = Uniform())
# We chose to create 2 houses to choose from.

# Have a look at some of the things we stored
println(problem_data.houses)

# julia> problem_data.houses
# 2-element Array{StudentHousing.House,1}:
# StudentHousing.House(2, 1, 634.796, 614.355)
# StudentHousing.House(1, 1, 557.96, 311.02)

# We have also cached all the possible combinations of characteristics
println(problem_data.all_characteristics)
# julia> problem_data.all_characteristics
# 6-element Array{StudentHousing.Characteristic,1}:
#  StudentHousing.Characteristic(1, 1, 1, 1)
#  StudentHousing.Characteristic(1, 1, 2, 1)
#  StudentHousing.Characteristic(2, 1, 1, 1)
#  StudentHousing.Characteristic(2, 1, 2, 1)
#  StudentHousing.Characteristic(2, 2, 1, 1)
#  StudentHousing.Characteristic(2, 2, 2, 1)

# Our houses could be described as
# house 1: 2 bedrooms, 1 bathroom, <800$,  >= 0 sqrt ft (fits characteristic 3)
# house 1: 2 bedrooms, 1 bathroom, <1000$, >= 0 sqrt ft (fits characteristic 4)
# house 2: 1 bedrooms, 1 bathroom, <800$,  >= 0 sqrt ft (fits characteristic 1)
# house 2: 1 bedrooms, 1 bathroom, <1000$, >= 0 sqrt ft (fits characteristic 2)

# Note that the second house fits the descriptions of the first and second set
# of characteristics. Some preference patterns will allow the first only, some
# will allow the first and second. We don't do anything special to prioritize
# one assignment over another at the moment (e.g. assign lowest rent when
# possible). (TODO)

# If we permitted any combination of approving/disapproving a characteristic,
# we would have 2^6 = 64 preference patterns. However we have cached information
# only about preference patterns that make logical sense.

# julia> println(length(problem_data.patterns_allow))
# 13
# So 13 patterns don't allow a person to be OK with characteristic x but not OK
# with characteristic y that dominates x (better in every single rankable
# feature).

# Build the model and solve
m_one_stage = onestagemodel(problem_data)
@assert solve(m_one_stage) == :Optimal

# Have a look at our solutions:
println(getvalue(m_one_stage[:investment]))
# [1.0, 1.0]
println(getvalue(m_one_stage[:assignment]))
# [1, 6] = 1.0 <------------------
# [1, 7] = 0.0
# [1,11] = 1.0 <------------------
# [1,12] = 0.0
# [1,13] = 0.0
# [2, 3] = 1.0 <------------------
# [2, 4] = 0.0
# [2, 5] = 0.0
# [2, 6] = -0.0
# [2, 7] = 0.0
# [2, 8] = 0.0
# [2, 9] = 0.0
# [2,10] = 0.0
# [2,11] = -0.0
# [2,12] = 0.0
# [2,13] = 0.0

# We have chosen to invest in both houses and assigned the first to one
# entity with preference pattern 6, and one with preference pattern 1.
# We assigned the second house to someone with preference pattern 3.

# Sanity check:
p = problem_data.patterns_allow[6]
# 3-element Array{Int64,1}:
#  1
#  3
#  5
p = problem_data.patterns_allow[11]
# 4-element Array{Int64,1}:
#  1
#  2
#  3
#  5
# ... shows us that preference pattern 6 allows characteristics set 3, and
# preference pattern 11 allows characteristic 3 (which house 1 fits).
p = problem_data.patterns_allow[3]
# 1-element Array{Int64,1}:
#  1
# ... shows us that preference pattern 3 allows characteristics set 1.

# ==============================================================================
# One stage, larger model.
# ==============================================================================
# Let's see how much we can scale up without any large-scale techniques,
# and investigate how much we lose by solving a linear relaxation of our
# problem.

# To scale up, we'll just increase the number of bedrooms allowed for now.

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

nbathrooms_range = collect(1:2)
nbathrooms_frequency = Weights([0.75; 0.25])
prices_range_pp = [800.0, 1000.0]
area_ranges = [0.0, 700.0, 850.0]
budget = 1000.0

for i = 1:2
    srand(1)
    nbedrooms_range, nbedrooms_frequency = bedrooms_scale(i)
    @time market_data = StudentHousing.MarketData(nbedrooms_range,
        nbedrooms_frequency, nbathrooms_range, nbathrooms_frequency,
        prices_range_pp, area_ranges)
    @time problem_data = StudentHousingData(market_data, nhouses = 50, budget = budget,
        demand_distribution = Uniform(0.0, 100.0))
    P = StudentHousing.get_npatterns(problem_data)
    println("Using $P patterns, solving MIP:")
    @time m_one_stage = onestagemodel(problem_data)
    # println("Assigned students = ", getvalue(sum(sum(m_one_stage[:assignment]))))
    tic()
    @assert solve(m_one_stage) == :Optimal
    toc()
    println("MIP objective = ", getobjectivevalue(m_one_stage))
    @assert solve(m_one_stage, relaxation = true) == :Optimal
    println("LP objective = ", getobjectivevalue(m_one_stage))
end

# 0.000004 seconds (1 allocation: 64 bytes)
# 0.000155 seconds (327 allocations: 319.641 KiB)
# Using 9 patterns, solving MIP:
# 0.000444 seconds (3.66 k allocations: 209.766 KiB)
# elapsed time: 0.016997735 seconds
# MIP objective = 474.0
# LP objective = 473.5585096078103
# 0.000005 seconds (1 allocation: 64 bytes)
# 1.222919 seconds (1.05 M allocations: 1.084 GiB, 25.72% gc time)
# Using 329 patterns, solving MIP:
# 0.011981 seconds (78.52 k allocations: 4.183 MiB)
# elapsed time: 0.045735724 seconds
# MIP objective = 16616.0
# LP objective = 16615.10611513201

# 0.000017 seconds (1 allocation: 64 bytes)
# too long outside of MIP on PC, 2^48 potential patterns to process

# Even when 2^ncharacteristics is too large to be stored, the
# number of legal patterns we get is only in the hundrends, and the MIP takes
# milliseconds to solve. The bottleneck is processing the patterns before we
# even get to the MIP.

# Let's focus on the multistage problem for a bit.

# ==============================================================================
# Multistage, medium model.
# ==============================================================================
srand(1)
nbedrooms_range = collect(1:2)
nbedrooms_frequency = Weights([0.75, 0.25])

market_data = StudentHousing.MarketData(nbedrooms_range,
    nbedrooms_frequency, nbathrooms_range, nbathrooms_frequency,
    prices_range_pp, area_ranges)

problem_data = StudentHousingData(market_data, nhouses = 50, budget = budget,
    demand_distribution = Uniform(0.0, 100.0), nstages = 1, nnoises = 1)

m_multi_stage = multistagemodel(problem_data)
solve(m_multi_stage, max_iterations = 5)

# converges extremely quickly... and Benders vs Lagrangian bounds v close
# IP: 148.660K LP: 148.651K

# Delve into more detail in regards to column generation with constraint
# generation
