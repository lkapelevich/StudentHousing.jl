
# look at this as though we generated x houses with characteristic c_i. they
# may as well be all the same thing, we'll still represent them as binaries rather than an integer number of houses with that characteristic
#
# number of possible preference patterns is at most 2^(max # of houses)
# although some patterns don't make sense and we would exclude them
#
# - redefine some variables
# - bundle preference patterns together and refine as we go
# -






using StudentHousing, JuMP, SDDP, SDDiP, StatsBase

srand(32)

# Before using bigger data, let's try a small example.

NBEDROOMS_RANGE = collect(1:2)
NBDROOMS_FREQCY = Weights([0.5, 0.5])
NBATHROOMS_RANGE = collect(1:2)
NBATHROOMS_FREQCY = Weights([0.5, 0.5])
PRICE_RANGES_PP = [800.0, 1000.0]
AREA_RANGES = [0.0]

# Prep data
market_data = StudentHousing.MarketData(NBEDROOMS_RANGE, NBDROOMS_FREQCY, NBATHROOMS_RANGE, NBATHROOMS_FREQCY, PRICE_RANGES_PP, AREA_RANGES)
budget = 1e6
problem_data = StudentHousingData(market_data, nhouses = 2, budget = budget)

# Build models
m_one_stage   = onestagemodel(problem_data)
m_multi_stage = multistagemodel(problem_data)

# Solve them
solve(m_one_stage)
solve(m_multi_stage, max_iterations = 8)


# One stage example:


# StudentHousing.Characteristic[StudentHousing.Characteristic(1, 1, 1, 1), StudentHousing.Characteristic(1, 1, 2, 1), StudentHousing.Characteristic(2, 1, 1, 1), StudentHousing.Characteristic(2, 1, 2, 1), StudentHousing.Characteristic(2, 2, 1, 1), StudentHousing.Characteristic(2, 2, 2, 1)]
# StudentHousing.House[StudentHousing.House(2, 1, 634.796, 614.355), StudentHousing.House(1, 1, 557.96, 311.02)]
