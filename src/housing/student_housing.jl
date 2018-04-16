using StatsBase, Distributions

# House data
struct House
    nbedrooms::Int
    nbathrooms::Int
    rent::Float64
    area::Float64
end
maintenance(h::House) = h.rent

# Market data
NBEDROOMS_RANGE = collect(1:7)
NBDROOMS_FREQCY = WeightVec([0.0078125, 0.5,  0.25,  0.125,  0.0625,  0.03125,  0.015625])
NBATHROOMS_RANGE = collect(1:5)
NBATHROOMS_FREQCY = WeightVec([0.5,  0.25,  0.125,  0.0625,  0.0625])
BUDGET = 1e7

function avg_area(nbedrooms::Int, nbathrooms::Int)
    nbedrooms * 360 + nbathrooms * 15
end
function avg_rent(nbedrooms::Int, nbathrooms::Int, area::Float64)
    area * 1.4 + nbathrooms * 50 - nbedrooms * 10
end

PRICE_RANGES_PP =
    [800 900 1000 1100 1200 1300 1400 1500 1600]

AREA_RANGES =
    [750 800 850 900 950 1000 1100 1200 1300 1400]

struct Characteristic
    nbedrooms::Int
    nbathrooms::Int
    price_at_most::Int
    area_at_least::Int
end

function house_fits_characteristic(house::House, characteristic::Characteristic)
    house.nbedrooms == characteristic.nbedrooms &&
    house.nbathrooms == characteristic.nbathrooms &&
    house.rent <= PRICE_RANGES_PP[characteristic.price_at_most] &&
    house.area >= AREA_RANGES[characteristic.area_at_least]
end

all_possible_characteristics = Characteristic[]
for nbed in NBEDROOMS_RANGE
    for nbath in NBATHROOMS_RANGE
        nbath > nbed && continue
        for p in 1:length(PRICE_RANGES_PP)
            for a in 1:length(AREA_RANGES)
                push!(all_possible_characteristics, Characteristic(nbed, nbath, p, a))
            end
        end
    end
end
C = length(all_possible_characteristics)
println(length(C)) # 3150

# There are 100 houses/apartments this semester
houses = House[]
srand(32)
nhouses = 100
for h = 1:nhouses
    nbedrooms = sample(NBEDROOMS_RANGE, NBDROOMS_FREQCY)
    nbathrooms = sample(NBATHROOMS_RANGE, NBATHROOMS_FREQCY)
    area = avg_area(nbedrooms, nbathrooms) + rand(Normal(0.0, 10.0))
    rent = avg_rent(nbedrooms, nbathrooms, area) + rand(Normal(0.0, 100.0))
    push!(houses, House(nbedrooms, nbathrooms, area, rent))
end

# look at this as though we generated x houses with characteristic c_i. they
# may as well be all the same thing, we'll still represent them as binaries rather than an integer number of houses with that characteristic

# number of possible preference patterns is at most 2^(max # of houses)
# although some patterns don't make sense and we would exclude them


# - redefine some variables
# - bundle preference patterns together and refine as we go
# -

# ==============================================================================
# One stage, small version of this

# Suppose there are only 10 possible combinations of characteristics that describe a house
small_c = 10
# All possible preference patterns
npatterns = 2^small_c
# Totally don't need to write this explictly but we'll do it anyway
string2vector(s::String) = parse.(split(s, ""))
# The i^th possible pattern, there are 2^C of them in total
explicit_pattern(i::Int) = string2vector(bin(i-1, small_c))

function house_fits_pattern(house::House, p::Int)
    # Get the explicit pattern
    pattern = explicit_pattern(p)
    # For every characteristic possible
    for (i, c) in enumerate(pattern)
        # Does this person's preference pattern allow this characteristic?
        c == 0 && continue
        # Check if the house fits the characteristic also
        house_fits_characteristic(house, all_possible_characteristics[i]) && return true
    end
    false
end
house_fits_pattern(i::Int, p::Int) = house_fits_pattern(houses[i], p)

# Number of houses needed by preference pattern p should be embedded in preference pattern p somehow
# ignore for now


beds_needed(p::Int) = 1.0
beds_avail(i::Int) = houses[i].nbedrooms
maintenance(i::Int) = maintenance(houses[i])


# ==============================================================================
# One stage, small version model
using JuMP, Gurobi, CPLEX

demand = round.(rand(npatterns) * 100)

function build_small_one_stage()
    m = Model(solver = GurobiSolver(OutputFlag=0))
    # m = Model(solver = CplexSolver(CPX_PARAM_SCRIND = 0, CPX_PARAM_MIPDISPLAY=0))
    @variables(m, begin
        shortage >= 0
        investment[1:nhouses], Bin
        assignment[1:nhouses, 1:npatterns], Int
    end)

    @constraints(m, begin
        shortage == sum(demand[p] - sum(assignment[i, p] for i = 1:nhouses) for p = 1:npatterns)
        [i = 1:nhouses], sum(house_fits_pattern(i, p) * assignment[i, p] * beds_needed(p) for  p = 1:npatterns) <= investment[i] * beds_avail(i)
        sum(investment[i] * maintenance(i) for i = 1:nhouses) <= BUDGET
    end)

    @objective(m, Min, shortage)
    m
end

m = build_small_one_stage()
solve(m)

# # Small scale two-stage
# using JuMP, Gurobi
# m = Model(sover = GurobiSolver(OutputFlag=0))
# @variables(m, begin
#     shortage >= 0, Int
# end)
#
# # Small scale multistage => try with SDDiP
# using SDDP, SDDiP, JuMP, Gurobi
# sddpm = Model(stages = )
