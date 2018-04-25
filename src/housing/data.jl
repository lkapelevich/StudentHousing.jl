"""
    House

Everything that makes a house a `House`.
"""
struct House
    nbedrooms::Int
    nbathrooms::Int
    rent::Float64
    area::Float64
end

"""
Describes the range of values we are dealing with.
"""
struct MarketData
    bedrooms_range::Vector{Int}
    bedrooms_frequencye::Weights
    bathrooms_range::Vector{Int}
    bathrooms_frequency::Weights
    prices_range_pp::Vector{Float64}
    area_range::Vector{Float64}
end

# # Market data
# NBEDROOMS_RANGE = collect(1:7)
# NBDROOMS_FREQCY = WeightVec([0.0078125, 0.5,  0.25,  0.125,  0.0625,  0.03125,  0.015625])
# NBATHROOMS_RANGE = collect(1:5)
# NBATHROOMS_FREQCY = WeightVec([0.5,  0.25,  0.125,  0.0625,  0.0625])
# PRICE_RANGES_PP =
#     [800 1000 1300 1500 1800 2200]
# AREA_RANGES =
#     [700  800 900 1000 1200 1400]

"""
    maintenance(h::House)

Monthly cost we take on having invested in house `h`.
"""
maintenance(h::House) = h.rent / 10

"""
Average square footage of a house with a given number of bedrooms.
"""
function avg_area(nbedrooms::Int, nbathrooms::Int)
    nbedrooms * 300 + nbathrooms * 15
end
"""
Average rent we expect for a house with a given number of bedrooms, bathrooms,
    and area.
"""
function avg_rent(nbedrooms::Int, nbathrooms::Int, area::Float64)
    area * 1.4 + nbathrooms * 50 - nbedrooms * 10
end

"""
    Characteristic

Everything that anyone ever cared about when choosing where to live.
"""
struct Characteristic
    nbedrooms::Int
    nbathrooms::Int
    price_at_most::Int
    area_at_least::Int
end

"""
    house_fits_characteristic(house::House, characteristic::Characteristic)

Returns a boolean depending on whether `house` fits a description given by
`characteristic`.
"""
function house_fits_characteristic(house::House, characteristic::Characteristic, md::MarketData)
    house.nbedrooms == characteristic.nbedrooms &&
    house.nbathrooms == characteristic.nbathrooms &&
    house.rent <= md.prices_range_pp[characteristic.price_at_most] &&
    house.area >= md.area_range[characteristic.area_at_least]
end

"""
This will become our column generation part later.
"""
function get_all_characteristics(md::MarketData)
    all_possible_characteristics = Characteristic[]
    for nbed in md.bedrooms_range
        for nbath in md.bathrooms_range
            nbath > nbed && continue
            for p in 1:length(md.prices_range_pp)
                for a in 1:length(md.area_range)
                    push!(all_possible_characteristics, Characteristic(nbed, nbath, p, a))
                end
            end
        end
    end
    all_possible_characteristics
end
# C = length(all_possible_characteristics)
# println(length(C)) # 3150

# There are 100 houses/apartments this semester
"""
    gethouses(nhouses::Int)

Get the houses that we expect will be available on the market. Since we have no
real data, we generate some synthetic ones here.
"""
function gethouses(nhouses::Int, md::MarketData)
    houses = House[]
    for h = 1:nhouses
        nbedrooms = sample(md.bedrooms_range, md.bedrooms_frequencye)
        nbathrooms = sample(md.bathrooms_range, md.bathrooms_frequency)
        area = avg_area(nbedrooms, nbathrooms) + rand(Normal(0.0, 10.0))
        rent = avg_rent(nbedrooms, nbathrooms, area) + rand(Normal(0.0, 100.0))
        push!(houses, House(nbedrooms, nbathrooms, rent, area))
    end
    houses
end

"""
    getdemand(npatterns::Int, nnoises::Int, nstages::Int, d::ContinuousDistribution)

Generates radnom demands for a problem where the number of periods is
`nstages` and we want `nnoises` possible realizations of demand each period.
All demands are sampled from `d`.
"""
function getdemand(npatterns::Int, nnoises::Int, nstages::Int, d::ContinuousDistribution)
    demands = Array{Float64,3}(npatterns, nnoises, nstages)
    for n in 1:nnoises
        demands[:, n, :] .= round.(rand(d, npatterns, nstages))
    end
    demands
end

struct StudentHousingData
    budget::Float64
    all_characteristics::Vector{Characteristic}
    houses::Vector{House}
    market_data::MarketData
    demands::Array{Float64,3}
end

function check_data(nhouses::Int, nnoises::Int)
    (nhouses > 0) && (nnoises > 0)
end

"""
    StudentHousingData(market_data; nstages::Int=1,
                            nhouses::Int=1,
                            nnoises::Int=1,
                            demand_distribution::ContinuousDistribution=Normal(100,10),
                            budget::Float64=1e6

Holds all data for the housing problem.
"""
function StudentHousingData(market_data; nstages::Int=1,
                            nhouses::Int=1,
                            nnoises::Int=1,
                            demand_distribution::ContinuousDistribution=Normal(100,10),
                            budget::Float64=1e6
                        )

    check_data(nhouses, nnoises) || error("Specified non-positive values for positive parameters.")
    all_characteristics = get_all_characteristics(market_data)
    houses = gethouses(nhouses, market_data)
    npatterns = 2^(length(all_characteristics))
    demands = getdemand(npatterns, nnoises, nstages, demand_distribution)
    StudentHousingData(budget, all_characteristics, houses, market_data, demands)
end

# Some helper functions

# Don't need to write this explictly but we'll do it anyway
string2vector(s::String) = parse.(split(s, ""))
# The i^th possible pattern, if there are 2^C of them in total
explicit_pattern(i::Int, c::Int) = string2vector(bin(i-1, c))
beds_avail(i::Int, houses::Vector{House}) = houses[i].nbedrooms
maintenance(i::Int, houses::Vector{House}) = maintenance(houses[i])
get_ncharacteristics(d::StudentHousingData) = length(d.all_characteristics)
get_npatterns(d::StudentHousingData) = 2^get_ncharacteristics(d)
