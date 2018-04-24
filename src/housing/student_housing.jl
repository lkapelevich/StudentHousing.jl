
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


# Houses are:
# StudentHousing.House(2, 1, 634.796, 614.355) fits char 3 only
# StudentHousing.House(1, 1, 557.96, 311.02) fits char 1 and char 2
# Which would be described as
# 2 bedrooms, 1 bathroom, <800$, >= 0 sqrt ft (char 3)
# 1 bedrooms, 1 bathroom, <800$, >= 0 sqrt ft (char 1)
# And not described as
# 1 bd, 1 bth, < 1000$, 0 (char 2)
# 2 bd, 1 bh, < 1000$ (char 4)
# 2 bd, 2 bth, < 800$ (char 5)
# 2 bd, 2 bth, < 1000$ (char 6) <-- didn't need to be considered because dominated, but included
# So house 1 can be assigned to any 2 ppl with preference pattern that allows characteristic 3
# House 2 can be assigned to anyone with preference pattern that allows characteristic 1

# julia> problem_data.all_characteristics
# 6-element Array{StudentHousing.Characteristic,1}:
#  StudentHousing.Characteristic(1, 1, 1, 1) <- house 2
#  StudentHousing.Characteristic(1, 1, 2, 1) <- house 2 also, but more expensive for the students
#  StudentHousing.Characteristic(2, 1, 1, 1) <- house 1
#  StudentHousing.Characteristic(2, 1, 2, 1)
#  StudentHousing.Characteristic(2, 2, 1, 1)
#  StudentHousing.Characteristic(2, 2, 2, 1)

a = zeros(2, 64)
for i = 1:2
    for p = 1:64
        a[i,p] = Int(StudentHousing.house_fits_pattern(i, p, problem_data))
    end
end
@assert 11 in find(a[1,:] .≈ 1)
@assert 15 in find(a[1,:] .≈ 1)
@assert 19 in find(a[2,:] .≈ 1)

for p = 1:64
    for i = 1:2
        (getvalue(m_one_stage[:assignment][i,p]) > 0) && (println(i, p))
    end
end
# 1 -> 11
# 1 -> 15
# 2 -> 19
StudentHousing.explicit_pattern(11, 6)
StudentHousing.explicit_pattern(15, 6)
StudentHousing.explicit_pattern(19, 6)

@assert StudentHousing.house_fits_characteristic(problem_data.houses[2], problem_data.all_characteristics[1], problem_data.market_data)
@assert StudentHousing.house_fits_characteristic(problem_data.houses[2], problem_data.all_characteristics[2], problem_data.market_data)

# TODO: what to do when there is a choice of rent for a student
