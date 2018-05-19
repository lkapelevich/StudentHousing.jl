# __precompile__()

module StudentHousing

using StatsBase, Distributions,
    JuMP, Gurobi, CPLEX, SDDP, SDDiP

export
    StudentHousingData,
    onestagemodel, multistagemodel, solve_house_generation, solve_ia_generation,
    solve_pattern_generation, solve_ia_p_generation,
    house_allowedby, house_fits_pattern, beds_needed, beds_avail

include("housing/binary_hacks.jl")
include("housing/data.jl")
include("housing/model.jl")
include("GAP/gap_h.jl")
include("GAP/gap_p.jl")
include("investandassign/h_investandassign.jl")
include("investandassign/p_investandassign.jl")

end # module
