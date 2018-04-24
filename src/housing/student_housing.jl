
# look at this as though we generated x houses with characteristic c_i. they
# may as well be all the same thing, we'll still represent them as binaries rather than an integer number of houses with that characteristic
#
# number of possible preference patterns is at most 2^(max # of houses)
# although some patterns don't make sense and we would exclude them
#
# - redefine some variables
# - bundle preference patterns together and refine as we go
# -






using StudentHousing, JuMP, SDDP, SDDiP

srand(32)

# Before using bigger data, let's try a small example.

# Suppose there are only 10 possible combinations of characteristics that describe a house
small_c = 10
# All possible preference patterns
npatterns = 2^small_c # TODO this is not always 2^c so should go into our data

budget = 1e6

# Get data
data = StudentHousingData(2, small_c, budget)

# Build models
m_one_stage   = onestagemodel(data)
m_multi_stage = multistagemodel(data)

# Solve them
solve(m_one_stage)
solve(m_multi_stage, max_iterations = 8)
