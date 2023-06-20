import Aqua
using BioStockholm

@testset "Aqua.test_all" begin
    showtestset()
    Aqua.test_all(BioStockholm)
end
