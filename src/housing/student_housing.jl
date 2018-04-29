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
# We created 2 houses to choose from. Later we will assume that houses
# available are deterministic, (we will always find enough on the market), and
# our bottleneck is the budget constraint.

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
# we would have 2^6 = 64 preference patterns. However we have cached a reference
# to all the preference patterns that make logical sense
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
println(find(getvalue(m_one_stage[:assignment][1,:])))
# [6, 11]
println(find(getvalue(m_one_stage[:assignment][2,:])))
# [3]
# We have chosen to invest in both houses and assigned the first to one
# entity with preference pattern 6, and one with preference pattern 1.
# We assigned the second house to someone with preference pattern 3.

# Some sanity checks:
p = problem_data.patterns_allow[6]
# 3-element Array{Int64,1}:
#  1
#  3
#  5
p = problem_data.patterns_allow[11]
println(StudentHousing.explicit_pattern(p, length(problem_data.all_characteristics)))
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


nbathrooms_range = collect(1:3)
nbathrooms_frequency = Weights([1.0])
prices_range_pp = [800.0, 1000.0]
area_ranges = [0.0, 700.0, 850.0]
budget = 200.0

for i = 1:4
    nbedrooms_range, nbedrooms_frequency = bedrooms_scale(i)
    @time market_data = StudentHousing.MarketData(nbedrooms_range,
        nbedrooms_frequency, nbathrooms_range, nbathrooms_frequency,
        prices_range_pp, area_ranges)
    @time problem_data = StudentHousingData(market_data, nhouses = 50, budget = budget,
        demand_distribution = Uniform(0.0, 100.0))
    P = StudentHousing.get_npatterns(problem_data)
    println("Using $P patterns, solving MIP:")
    @time m_one_stage = onestagemodel(problem_data)
    println("Assigned students = ", sum(sum(getvalue(m_one_stage[:assignment]))))
    tic()
    @assert solve(m_one_stage) == :Optimal
    toc()
    println("MIP objective = ", getobjectivevalue(m_one_stage))
    @assert solve(m_one_stage, relaxation = true) == :Optimal
    println("LP objective = ", getobjectivevalue(m_one_stage))
end

Using 5 patterns, solving MIP:
elapsed time: 0.005869044 seconds
MIP objective = 221.0
LP objective = 220.6994099433357
Using 19 patterns, solving MIP:
elapsed time: 0.007129354 seconds
MIP objective = 872.0
LP objective = 871.1601626430233
Using 49 patterns, solving MIP:
elapsed time: 0.018248958 seconds
MIP objective = 2608.0
LP objective = 2607.484000625551
Using 104 patterns, solving MIP:
elapsed time: 0.03236909 seconds
MIP objective = 5143.0
LP objective = 5142.340753401601
Using 195 patterns, solving MIP:
elapsed time: 0.069422402 seconds
MIP objective = 9696.0
elapsed time: 0.050716509 seconds
LP objective = 9695.738512578479




# m_multi_stage = multistagemodel(problem_data)
