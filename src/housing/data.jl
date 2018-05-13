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
    bedrooms_frequency::Weights
    bathrooms_range::Vector{Int}
    bathrooms_frequency::Weights
    prices_range_pp::Vector{Float64}
    area_range::Vector{Float64}
end

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

"""
    gethouses(nhouses::Int)

Get the houses that we expect will be available on the market. Since we have no
real data, we generate some synthetic ones here.
"""
function gethouses(nhouses::Int, md::MarketData)
    @assert minimum(md.bathrooms_range) <= minimum(md.bedrooms_range)
    houses = House[]
    for h = 1:nhouses
        nbedrooms = sample(md.bedrooms_range, md.bedrooms_frequency)
        nbathrooms = 1
        while true
            nbathrooms = sample(md.bathrooms_range, md.bathrooms_frequency)
            (nbathrooms <= nbedrooms) && break
        end
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

"""
    function dominates(c1::Characteristic, c2::Characteristic)

Returns true if `c1` dominates `c2`.
"""
function dominates(c1::Characteristic, c2::Characteristic)
    (c1.nbedrooms <= c2.nbedrooms) && # fewer roommates
    (c1.nbathrooms >= c2.nbathrooms) &&
    (c1.price_at_most <= c2.price_at_most) &&
    (c1.area_at_least >= c2.area_at_least)
end

"""
    pattern_is_legal(p::Vector{Int}, all_characteristics::Vector{Characteristic})

Checks whether there are logical conflicts in the characteristics referenced
within `p`.
"""
function pattern_is_legal(p::Vector{Int}, all_characteristics::Vector{Characteristic})
    for i = 1:length(p)
        if p[i] == 1
            # check that it is not dominated by anything with a 0
            for j = 1:length(p)
                i == j && continue
                if p[j] == 0 && dominates(all_characteristics[j], all_characteristics[i])
                    return false
                end
            end
        end
    end
    # Didn't find any conflicts, so if not empty, then pattern is legal
    true
end

function make_all_patterns(all_characteristics::Vector{Characteristic})
    all_patterns = Vector{Int}[]
    p = zeros(Int, length(all_characteristics))
    while true
        addone!(p)
        if pattern_is_legal(p, all_characteristics)
            push!(all_patterns, copy(p))
        end
        if all(p .== 1)
            break
        end
    end
    all_patterns
end

function beds_needed(p::Int, easy::Bool=true)
    if easy
        ones(p)
    else
        round.(rand(Uniform(1.0, 3.0), p))
    end
end

struct StudentHousingData
    nstages::Int
    budget::Float64
    all_characteristics::Vector{Characteristic}
    houses::Vector{House}
    market_data::MarketData
    demands::Array{Float64,3}
    patterns_allow::Vector{Vector{Int}}
    beds_needed::Vector{Int}
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
                            budget::Float64=1e6,
                            easy::Bool=true
                        )

    check_data(nhouses, nnoises) || error("Specified non-positive values for positive parameters.")
    # Get all possible combinations of market characteristics
    all_characteristics = get_all_characteristics(market_data)
    # Generate some data describing houses
    houses = gethouses(nhouses, market_data)

    # Isolate only the patterns that make logical sense without ever computing
    # all patterns
    patterns = make_all_patterns(all_characteristics)
    # Cache characteristics each pattern will allow
    npatterns = length(patterns)
    patterns_sparse = Vector{Vector{Int}}(npatterns)
    for i = 1:npatterns
        patterns_sparse[i] = find(patterns[i] .> 0)
    end
    bedsneeded = beds_needed(npatterns, easy)

    # The number of patterns is the number of logically sound patterns
    npatterns = length(patterns_sparse)
    # Generate demand data
    demands = getdemand(npatterns, nnoises, nstages, demand_distribution)
    StudentHousingData(nstages, budget, all_characteristics, houses,
        market_data, demands, patterns_sparse, bedsneeded)
end

# Some helper functions

beds_avail(i::Int, houses::Vector{House}) = houses[i].nbedrooms
maintenance(i::Int, houses::Vector{House}) = maintenance(houses[i])
get_ncharacteristics(d::StudentHousingData) = length(d.all_characteristics)
get_npatterns(d::StudentHousingData) = length(d.patterns_allow)
beds_needed(p::Int, d::StudentHousingData) = d.beds_needed[p]
