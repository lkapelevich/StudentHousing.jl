# If not integer...
function solve_ip!(m::JuMP.Model, d::StudentHousingData)
    for i = 1:nhouses
        setcategory(m[:λ][i], :Bin)
    end
    for λnew in λ_generated
        setcategory(λnew, :Bin)
    end
    @assert solve(m) == :Optimal
    m
end

function recover_integer_soln(m::JuMP.Model, d::StudentHousingData)
    solve_ip!(m, d)

    # In case one of our initial columns was in the optimal basis
    results = zeros(nhouses, length(d.patterns_allow))
    for k = 1:nhouses
        if getvalue(m[:λ][k]) ≈ 1.0
            results[k, StudentHousing.house_allowedby(k, d)[1]] = 1.0
        end
    end
    # Check all the other columns we added
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
    results
end

# If not integer...
function recover_integer_soln_p(m::JuMP.Model, d::StudentHousingData)
    solve_ip!(m, d)
    npatterns = length(d.patterns_allow)

    results = zeros(nhouses, length(d.patterns_allow))
    for k = 1:npatterns
        if getvalue(m[:λ][k]) ≈ 1.0
            for i = 1:nhouses
                if house_fits_pattern(i, k, d)
                    results[i, k] .= 1.0
                    break
                end
            end
        end
    end
    # Check all the other columns we added
    for k = 1:length(U_generated)
        if getvalue(λ_generated[k]) ≈ 1.0
            # Find the assignment that we picked for our house
            houses = find(U_generated[k] .≈ 1.0)
            # Check the pattern index
            p = pattern_choice[k]
            # Mark the assignment
            results[houses, p] .= 1.0
        end
    end
    results
end
