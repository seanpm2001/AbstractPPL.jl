using AbstractPPL
using Documenter
using Test

@testset "AbstractPPL.jl" begin
    include("deprecations.jl")

    @testset "doctests" begin
        DocMeta.setdocmeta!(
            AbstractPPL,
            :DocTestSetup,
            quote
            using AbstractPPL
            end;
            recursive=true,
        )
        doctest(AbstractPPL; manual=false)
    end
end

