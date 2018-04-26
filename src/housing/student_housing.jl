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

# Build the model and solve
m_one_stage = onestagemodel(problem_data)
@assert solve(m_one_stage) == :Optimal

# Have a look at our solutions:
println(getvalue(m_one_stage[:investment]))
println(find(getvalue(m_one_stage[:assignment][1,:])))
# [6, 15]
println(find(getvalue(m_one_stage[:assignment][2,:])))
# [19]
# We have chosen to invest in both houses and assigned the first to one
# entity with preference pattern 6, and one with preference pattern 15.
# We assigned the second house to someone with preference pattern 19.
p = problem_data.legal_pattern_indices[6]
println(StudentHousing.explicit_pattern(p, length(problem_data.all_characteristics)))
# Shows us that preference pattern 6 allows characteristics set 4.
p = problem_data.legal_pattern_indices[19]
println(StudentHousing.explicit_pattern(p, length(problem_data.all_characteristics)))
# Shows us that preference pattern 19 allows characteristics set 2.

# ==============================================================================
# One stage, larger model.
# ==============================================================================
# Let's see how much we can scale up without any large-scale techniques.
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
# P = StudentHousing.get_npatterns(problem_data)






# m_multi_stage = multistagemodel(problem_data)
