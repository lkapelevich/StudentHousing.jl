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
println(problem_data.legal_pattern_indices)
# [3, 4, 33, 35, 36, 43, 44, 49, 51, 52, 59, 60, 64]
# These patterns don't allow a person to be OK with characteristic x but not OK
# with characteristic y that dominates x (better in every single feature).

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
p = problem_data.legal_pattern_indices[6]
println(StudentHousing.explicit_pattern(p, length(problem_data.all_characteristics)))
# [1, 0, 1, 0, 1, 0]
p = problem_data.legal_pattern_indices[11]
println(StudentHousing.explicit_pattern(p, length(problem_data.all_characteristics)))
# [1, 1, 1, 0, 1, 0]
# ... shows us that preference pattern 6 allows characteristics set 3, and
# preference pattern 11 allows characteristic 3 (which house 1 fits).
p = problem_data.legal_pattern_indices[3]
println(StudentHousing.explicit_pattern(p, length(problem_data.all_characteristics)))
# [1, 0, 0, 0, 0, 0]
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


nbathrooms_range = collect(1:1)
nbathrooms_frequency = Weights([1.0])
prices_range_pp = [800.0]
area_ranges = [0.0]
budget = 1e6

for i = 1:5
    nbedrooms_range, nbedrooms_frequency = bedrooms_scale(i)
    market_data = StudentHousing.MarketData(nbedrooms_range,
        nbedrooms_frequency, nbathrooms_range, nbathrooms_frequency,
        prices_range_pp, area_ranges)
    problem_data = StudentHousingData(market_data, nhouses = 2, budget = budget,
        demand_distribution = Uniform())
    P = StudentHousing.get_npatterns(problem_data)
    println("Using $P patterns, solving MIP:")
    @show problem_data.legal_pattern_indices
    m_one_stage = onestagemodel(problem_data)
    tic()
    @assert solve(m_one_stage) == :Optimal
    toc()
    println("MIP objective = ", getobjectivevalue(m_one_stage))
    tic()
    @assert solve(m_one_stage, relaxation = true) == :Optimal
    toc()
    println("LP objective = ", getobjectivevalue(m_one_stage))
end





# m_multi_stage = multistagemodel(problem_data)
