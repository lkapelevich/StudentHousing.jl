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
nhouses = 2
problem_data = StudentHousingData(market_data, nhouses = nhouses, budget = budget, demand_distribution = Uniform())

@testset "Helper functions" begin
    npatterns = StudentHousing.get_npatterns(problem_data)
    @test npatterns == 13
    a = zeros(2, 64)
    for i = 1:2
        for p = 1:npatterns
            a[i,p] = Int(StudentHousing.house_fits_pattern(i, p, problem_data))
        end
    end
    @test 6  in find(a[1,:] .≈ 1) # 6th  pattern allows house 1
    @test 11 in find(a[1,:] .≈ 1) # 11th pattern allows house 1
    @test 3  in find(a[2,:] .≈ 1) # 3rd  pattern allows house 2

    @test StudentHousing.house_fits_characteristic(problem_data.houses[1], problem_data.all_characteristics[3], problem_data.market_data)
    @test StudentHousing.house_fits_characteristic(problem_data.houses[1], problem_data.all_characteristics[4], problem_data.market_data)
    @test StudentHousing.house_fits_characteristic(problem_data.houses[2], problem_data.all_characteristics[1], problem_data.market_data)
    @test StudentHousing.house_fits_characteristic(problem_data.houses[2], problem_data.all_characteristics[2], problem_data.market_data)

    @testset "Illegal patterns" begin
        # Characteristic (1,1,1,1) (char 1) dominates (1,1,2,1)  (char 2) (same features but higher cost)
        # An illegal pattern would be [0 1 x x x x]
        @test StudentHousing.pattern_is_legal([0, 1, 0, 0, 0, 0], problem_data.all_characteristics) == false
        @test StudentHousing.pattern_is_legal([0, 1, 0, 1, 0, 0], problem_data.all_characteristics) == false
        all_patterns = StudentHousing.make_all_patterns(problem_data.all_characteristics)
        @test length(all_patterns) == 13
    end
end

@testset "Single stage deterministic" begin

    # Build models
    m_one_stage   = onestagemodel(problem_data)

    # Solve them
    solve(m_one_stage)

    @test getobjectivevalue(m_one_stage) ≈ 2.0
    @test getvalue(m_one_stage[:assignment][1,  6]) ≈ 1.0
    @test getvalue(m_one_stage[:assignment][1, 11]) ≈ 1.0
    @test getvalue(m_one_stage[:assignment][2,  3]) ≈ 1.0

end

@testset "Column Generation Approaches" begin
    nhouses = 3
    problem_data = StudentHousingData(market_data, nhouses = nhouses, budget = budget, demand_distribution = Uniform(0.9, 1.1))
    @testset "GAP" begin
        m, V_generated, λ_generated, house_choice = solve_house_generation(problem_data)
        results = zeros(nhouses, length(problem_data.patterns_allow))
        for k = 1:nhouses
            if getvalue(m[:λ][k]) ≈ 1.0
                results[k, StudentHousing.house_allowedby(k, problem_data)[1]] = 1.0
            end
        end
        for k = 1:length(V_generated)
            if getvalue(λ_generated[k]) ≈ 1.0
                # Find the assignment that we picked for our house
                patterns = find(V_generated[k] .≈ 1.0)
                # Check the house index
                h = house_choice[k]
                # Mark the assignment
                results[h, patterns] .= 1.0
            end
        end
        for h = 1:nhouses
            for p in find(results[h,:] .≈ 1.0)
                @test p in StudentHousing.house_allowedby(h, problem_data)
            end
        end
    end

    @testset "Invest and Assign" begin
        m, V_generated, λ_generated, house_choice = solve_ia_generation(problem_data)
        results = zeros(nhouses, length(problem_data.patterns_allow))
        for k = 1:nhouses
            if getvalue(m[:λ][k]) ≈ 1.0
                results[k, StudentHousing.house_allowedby(k, problem_data)[1]] = 1.0
            end
        end
        for k = 1:length(V_generated)
            if getvalue(λ_generated[k]) ≈ 1.0
                # Find the assignment that we picked for our house
                patterns = find(V_generated[k] .≈ 1.0)
                # Check the house index
                h = house_choice[k]
                # Mark the assignment
                results[h, patterns] .= 1.0
            end
        end
        for h = 1:nhouses
            for p in find(results[h,:] .≈ 1.0)
                @test p in StudentHousing.house_allowedby(h, problem_data)
            end
        end
    end
end
