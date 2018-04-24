module StudentHousing

using StatsBase, Distributions,
    JuMP, Gurobi, CPLEX, SDDP, SDDiP

export
    StudentHousingData,
    onestagemodel, multistagemodel

include("housing/data.jl")
include("housing/model.jl")

end # module
