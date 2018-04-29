

function addone!(a::Vector{Int})
    for i = reverse(1:length(a))
        if a[i] == 0
            a[i] = 1
            return
        else
            a[i] = 0
        end
    end
    # error("Overflow adding 1 to $a".)
end
