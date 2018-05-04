# __precompile__()

module StudentHousing

using StatsBase, Distributions,
    JuMP, Gurobi, CPLEX, SDDP, SDDiP

export
    StudentHousingData,
    onestagemodel, multistagemodel, solve_house_generation,
    house_allowedby, house_fits_pattern, beds_needed, beds_avail

include("housing/binary_hacks.jl")
include("housing/data.jl")
include("housing/model.jl")
include("GAP/gap_h.jl")

end # module
