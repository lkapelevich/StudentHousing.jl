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

# Market data
NBEDROOMS_RANGE = collect(1:7)
NBDROOMS_FREQCY = WeightVec([0.0078125, 0.5,  0.25,  0.125,  0.0625,  0.03125,  0.015625])
NBATHROOMS_RANGE = collect(1:5)
NBATHROOMS_FREQCY = WeightVec([0.5,  0.25,  0.125,  0.0625,  0.0625])
PRICE_RANGES_PP =
    [800 900 1000 1100 1200 1300 1400 1500 1600]
AREA_RANGES =
    [750 800 850 900 950 1000 1100 1200 1300 1400]

"""
    maintenance(h::House)

Monthly cost we take on having invested in house `h`.
"""
maintenance(h::House) = h.rent / 10

"""
Average square footage of a house with a given number of bedrooms.
"""
function avg_area(nbedrooms::Int, nbathrooms::Int)
    nbedrooms * 360 + nbathrooms * 15
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
function house_fits_characteristic(house::House, characteristic::Characteristic)
    house.nbedrooms == characteristic.nbedrooms &&
    house.nbathrooms == characteristic.nbathrooms &&
    house.rent <= PRICE_RANGES_PP[characteristic.price_at_most] &&
    house.area >= AREA_RANGES[characteristic.area_at_least]
end

"""
This will become our column generation part later.
"""
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
"""
    gethouses(nhouses::Int)

Get the houses that we expect will be available on the market. Since we have no
real data, we generate some synthetic ones here.
"""
function gethouses(nhouses::Int)
    houses = House[]
    for h = 1:nhouses
        nbedrooms = sample(NBEDROOMS_RANGE, NBDROOMS_FREQCY)
        nbathrooms = sample(NBATHROOMS_RANGE, NBATHROOMS_FREQCY)
        area = avg_area(nbedrooms, nbathrooms) + rand(Normal(0.0, 10.0))
        rent = avg_rent(nbedrooms, nbathrooms, area) + rand(Normal(0.0, 100.0))
        push!(houses, House(nbedrooms, nbathrooms, area, rent))
    end
    houses
end

"""
    StudentHousingData(nhouses::Int=1, ncharacteristics::Int=1, budget::Float64=1e6)

Holds all data for the housing problem.
"""
struct StudentHousingData
    nhouses::Int
    ncharacteristics::Int
    budget::Float64
end
StudentHousingData() = StudentHousingData(1, 1, 1e6)
