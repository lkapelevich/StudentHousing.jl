using StudentHousing
using Base.Test
using JuMP, SDDP, SDDiP, StatsBase, Distributions

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
problem_data = StudentHousingData(market_data, nhouses = 2, budget = budget, demand_distribution = Uniform())

@testset "Helper functions" begin
    a = zeros(2, 64)
    for i = 1:2
        for p = 1:64
            a[i,p] = Int(StudentHousing.house_fits_pattern(i, p, problem_data))
        end
    end
    @test 11 in find(a[1,:] .≈ 1)
    @test 15 in find(a[1,:] .≈ 1)
    @test 19 in find(a[2,:] .≈ 1)

    @test StudentHousing.house_fits_characteristic(problem_data.houses[2], problem_data.all_characteristics[1], problem_data.market_data)
    @test StudentHousing.house_fits_characteristic(problem_data.houses[2], problem_data.all_characteristics[2], problem_data.market_data)

    @testset "Illegal patterns" begin
        # Characteristic (1,1,1,1) (char 1) dominates (1,1,2,1)  (char 2) (same features but higher cost)
        # An illegal pattern would be [0 1 x x x x] e.g. [0 1 0 0 0 0] = pattern 2^2 + 1 = 5
        for i = [0, 4, 8]
            @test StudentHousing.pattern_is_legal(5 + 1, problem_data.all_characteristics) == false
        end
    end
end

@testset "Single stage deterministic" begin

    # Build models
    m_one_stage   = onestagemodel(problem_data)

    # Solve them
    solve(m_one_stage)

    @test getobjectivevalue(m_one_stage) ≈ 26.0
    @test getvalue(m_one_stage[:assignment][1, 11]) ≈ 1.0
    @test getvalue(m_one_stage[:assignment][1, 15]) ≈ 1.0
    @test getvalue(m_one_stage[:assignment][2, 19]) ≈ 1.0


end
