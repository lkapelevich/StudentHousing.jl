# =============================================================================
# Compare with original single-stage MIP, 329 pattern example
# =============================================================================
nbedrooms_range = collect(1:2)
nbedrooms_frequency = Weights([0.75, 0.25])
nbathrooms_range = collect(1:2)
nbathrooms_frequency = Weights([0.75; 0.25])
prices_range_pp = [800.0, 1000.0]
area_ranges = [0.0, 700.0, 850.0]
budget = 1000.0
market_data = StudentHousing.MarketData(nbedrooms_range, nbedrooms_frequency,
    nbathrooms_range, nbathrooms_frequency, prices_range_pp, area_ranges)
nhouses = 50
srand(1)
d = StudentHousingData(market_data, nhouses = nhouses, budget = budget,
                  demand_distribution = Uniform(0.0, 100.0))

# =============================================================================
# Solve problem with column generation algorithm, pattern subproblems
# =============================================================================
tic()
m3, U_generated, λ_generated, pattern_choice = solve_ia_p_generation(d)
toc()
# elapsed time: 15.290560206 seconds

# =============================================================================
# Look at solution
# =============================================================================
println(getobjectivevalue(m3))
# 25.81671609417941
println("Shortage = ", sum(sum(d.demands)) - getobjectivevalue(m3))
# Shortage = 16615.18328390582
# ... this is equal to the LP relaxation

# Not integer, so get integer solution with existing columns
r = recover_integer_soln_p(m3, d)
println("Integer shortage = ", sum(sum(d.demands)) - sum(sum(r)))
# Integer shortage = 16616.0
# ... which matches the MIP solution

# =============================================================================
# Solve problem with column generation algorithm, pattern subproblems
# without looking for best reduced cost, stop @ any positive reduced cost
# =============================================================================
# srand(32)
# d = StudentHousingData(market_data, nhouses = 2, budget = budget,
#                   demand_distribution = Uniform(0.0, 100.0))
tic()
m3, U_generated, λ_generated, pattern_choice = solve_ia_p_generation(d, true)
toc()
# too long on PC
