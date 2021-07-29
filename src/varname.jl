using Setfield
import Setfield: PropertyLens, ComposedLens, IdentityLens, IndexLens, DynamicIndexLens

"""
    VarName{sym}(indexing::Tuple=())

A variable identifier for a symbol `sym` and indices `indexing` in the format
returned by [`@vinds`](@ref).

The Julia variable in the model corresponding to `sym` can refer to a single value or to a
hierarchical array structure of univariate, multivariate or matrix variables. The field `indexing`
stores the indices requires to access the random variable from the Julia variable indicated by `sym`
as a tuple of tuples. Each element of the tuple thereby contains the indices of one indexing
operation.

`VarName`s can be manually constructed using the `VarName{sym}(indexing)` constructor, or from an
indexing expression through the [`@varname`](@ref) convenience macro.

# Examples

```jldoctest
julia> vn = VarName{:x}(((Colon(), 1), (2,)))
x[:,1][2]

julia> vn.indexing
((Colon(), 1), (2,))

julia> @varname x[:, 1][1+1]
x[:,1][2]
```
"""
struct VarName{sym, T}
    indexing::T

    VarName{sym}(indexing=()) where {sym} = new{sym,typeof(indexing)}(indexing)
end

"""
    VarName(vn::VarName, indexing=())

Return a copy of `vn` with a new index `indexing`.

```jldoctest
julia> VarName(@varname(x[1][2:3]), ((2,),))
x[2]

julia> VarName(@varname(x[1][2:3]))
x
```
"""
function VarName(vn::VarName, indexing = ())
    return VarName{getsym(vn)}(indexing)
end


"""
    getsym(vn::VarName)

Return the symbol of the Julia variable used to generate `vn`.

## Examples

```jldoctest
julia> getsym(@varname(x[1][2:3]))
:x

julia> getsym(@varname(y))
:y
```
"""
getsym(vn::VarName{sym}) where sym = sym


"""
    getindexing(vn::VarName)

Return the indexing tuple of the Julia variable used to generate `vn`.

## Examples

```jldoctest
julia> getindexing(@varname(x[1][2:3]))
(@lens _[1][2:3])

julia> getindexing(@varname(y))
()
```
"""
getindexing(vn::VarName) = vn.indexing


Base.hash(vn::VarName, h::UInt) = hash((getsym(vn), getindexing(vn)), h)
Base.:(==)(x::VarName, y::VarName) = getsym(x) == getsym(y) && getindexing(x) == getindexing(y)

function Base.show(io::IO, vn::VarName{<:Any, <:Tuple})
    print(io, getsym(vn))
    for indices in getindexing(vn)
        print(io, "[")
        join(io, map(prettify_index, indices), ",")
        print(io, "]")
    end
end

function Base.show(io::IO, vn::VarName{<:Any, <:Lens})
    print(io, getsym(vn))
    _print_application(io, vn.indexing)
end

_print_application(io::IO, l::Lens) = Setfield.print_application(io, l)
function _print_application(io::IO, l::ComposedLens)
    _print_application(io, l.outer)
    _print_application(io, l.inner)
end
_print_application(io::IO, l::IndexLens) = print(io, "[", join(map(prettify_index, l.indices), ","), "]")
# This is a bit weird but whatever. We're almost always going to
# `concretize` anyways.
_print_application(io::IO, l::DynamicIndexLens) = print(io, l, "(_)")

prettify_index(x) = string(x)
prettify_index(::Colon) = ":"

"""
    Symbol(vn::VarName)

Return a `Symbol` represenation of the variable identifier `VarName`.

```jldoctest
julia> Symbol(@varname(x[1][2:3]))
Symbol("x[1][2:3]")
```
"""
Base.Symbol(vn::VarName) = Symbol(string(vn))  # simplified symbol


"""
    inspace(vn::Union{VarName, Symbol}, space::Tuple)

Check whether `vn`'s variable symbol is in `space`.  The empty tuple counts as the "universal space"
containing all variables.  Subsumption (see [`subsume`](@ref)) is respected.

## Examples

```jldoctest
julia> inspace(@varname(x[1][2:3]), ())
true

julia> inspace(@varname(x[1][2:3]), (:x,))
true

julia> inspace(@varname(x[1][2:3]), (@varname(x),))
true

julia> inspace(@varname(x[1][2:3]), (@varname(x[1:10]), :y))
true

julia> inspace(@varname(x[1][2:3]), (@varname(x[:][2:4]), :y))
true

julia> inspace(@varname(x[1][2:3]), (@varname(x[1:10]),))
true
```
"""
inspace(vn, space::Tuple{}) = true # empty tuple is treated as universal space
inspace(vn, space::Tuple) = vn in space
inspace(vn::VarName, space::Tuple{}) = true
inspace(vn::VarName, space::Tuple) = any(_in(vn, s) for s in space)

_in(vn::VarName, s::Symbol) = getsym(vn) == s
_in(vn::VarName, s::VarName) = subsumes(s, vn)


"""
    subsumes(u::VarName, v::VarName)

Check whether the variable name `v` describes a sub-range of the variable `u`.  Supported
indexing:

  - Scalar:

  ```jldoctest
  julia> subsumes(@varname(x), @varname(x[1, 2]))
  true
  
  julia> subsumes(@varname(x[1, 2]), @varname(x[1, 2][3]))
  true
  ```
  
  - Array of scalar: basically everything that fulfills `issubset`.
  
  ```jldoctest
  julia> subsumes(@varname(x[[1, 2], 3]), @varname(x[1, 3]))
  true
  
  julia> subsumes(@varname(x[1:3]), @varname(x[2][1]))
  true
  ```
  
  - Slices:
  
  ```jldoctest
  julia> subsumes(@varname(x[2, :]), @varname(x[2, 10][1]))
  true
  ```

Currently _not_ supported are: 

  - Boolean indexing, literal `CartesianIndex` (these could be added, though)
  - Linear indexing of multidimensional arrays: `x[4]` does not subsume `x[2, 2]` for a matrix `x`
  - Trailing ones: `x[2, 1]` does not subsume `x[2]` for a vector `x`
"""
function subsumes(u::VarName, v::VarName)
    return getsym(u) == getsym(v) && subsumes(u.indexing, v.indexing)
end

subsumes(::Tuple{}, ::Tuple{}) = true  # x subsumes x
subsumes(::Tuple{}, ::Tuple) = true    # x subsumes x[1]
subsumes(::Tuple, ::Tuple{}) = false   # x[1] does not subsume x
function subsumes(t::Tuple, u::Tuple)  # does x[i]... subsume x[j]...?
    return _issubindex(first(t), first(u)) && subsumes(Base.tail(t), Base.tail(u))
end

const AnyIndex = Union{Int, AbstractVector{Int}, Colon} 
_issubindex_(::Tuple{Vararg{AnyIndex}}, ::Tuple{Vararg{AnyIndex}}) = false
function _issubindex(t::NTuple{N, AnyIndex}, u::NTuple{N, AnyIndex}) where {N}
    return all(_issubrange(j, i) for (i, j) in zip(t, u))
end

const ConcreteIndex = Union{Int, AbstractVector{Int}} # this include all kinds of ranges

"""Determine whether indices `i` are contained in `j`, treating `:` as universal set."""
_issubrange(i::ConcreteIndex, j::ConcreteIndex) = issubset(i, j)
_issubrange(i::Union{ConcreteIndex, Colon}, j::Colon) = true
_issubrange(i::Colon, j::ConcreteIndex) = true

# E.g. `x`, `x[1]`, i.e. `u` is always subsumed by `t`
subsumes(t::Tuple{}, u::Lens) = true

# Idea behind `subsumes` for `Lens` is that we traverse the two lenses in parallel,
# checking `subsumes` for every level. This for example means that if we are comparing
# `PropertyLens{:a}` and `PropertyLens{:b}` we immediately know that they do not subsume
# each other since at the same level/depth they access different properties.
subsumes(t::ComposedLens, u::ComposedLens) = subsumes(t.outer, u.outer) && subsumes(t.inner, u.inner)

# If `t` is still a composed lens, then there is no way it can subsume `u` since `u` is a
# leaf of the "lens-tree".
subsumes(t::ComposedLens, u::PropertyLens) = false
# Here we need to check if `u.outer` (i.e. the next lens to be applied from `u`) is
# subsumed by `t`, since this would mean that the rest of the composition is also subsumed
# by `t`.
subsumes(t::PropertyLens, u::ComposedLens) = subsumes(t, u.outer)

# For `PropertyLens` either they have the same `name` and thus they are indeed the same.
subsumes(t::PropertyLens{name}, u::PropertyLens{name}) where {name} = true
# Otherwise they represent different properties, and thus are not the same.
subsumes(t::PropertyLens, u::PropertyLens) = false

# Indices subsumes if they are subindices, i.e. we just call `_issubindex`.
# FIXME: Does not support `DynamicIndexLens`.
# FIXME: Does not correctly handle cases such as `subsumes(x, x[:])`
#        (but neither did old implementation).
subsumes(t::IndexLens, u::IndexLens) = subsumes(t.indices, u.indices)
subsumes(t::ComposedLens{<:IndexLens}, u::ComposedLens{<:IndexLens}) = subsumes_index(t, u)
subsumes(t::IndexLens, u::ComposedLens{<:IndexLens}) = subsumes_index(t, u)
subsumes(t::ComposedLens{<:IndexLens}, u::IndexLens) = subsumes_index(t, u)

# Since expressions such as `x[:][:][:][1]` and `x[1]` are equal,
# the indexing behavior must be considered jointly.
# Therefore we must recurse until we reach something that is NOT
# indexing, and then consider the sequence of indices leading up to this.
function subsumes_index(t, u)
    t_indices, t_next = combine_indices(t)
    u_indices, u_next = combine_indices(u)

    # Check if the indices indicate that `t` subsumes `u`.
    if !subsumes(t_indices, u_indices)
        return false
    end

    if t_next === nothing
        # Means that there's nothing left for `t` and either nothing
        # or something left for `u`, i.e. `t` indeed `subsumes` `u`.
        return true
    else
        # `t` only `subsumes` `u` if `u_next` is also nothing.
        if u_next === nothing
            return true
        else
            return false
        end
    end

    # If neither is `nothing` we continue iterating.
    return subsumes(t_next, u_next)
end

combine_indices(lens::Lens) = (), lens
combine_indices(lens::IndexLens) = (lens.indices, ), nothing
function combine_indices(lens::ComposedLens{<:IndexLens})
    indices, next = combine_indices(lens.inner)
    return (lens.outer.indices, indices...), next
end

"""
    concretize(l::Lens, x)

Return `l` instantiated on `x`, i.e. any runtime information evaluated using `x`.
"""

concretize(I::Lens, x) = I
concretize(I::DynamicIndexLens, x) = IndexLens(I.f(x))
function concretize(I::ComposedLens, x)
    x_inner = get(x, I.outer)
    return ComposedLens(concretize(I.outer, x), concretize(I.inner, x_inner))
end
"""
    concretize(vn::VarName, x)

Return `vn` instantiated on `x`, i.e. any runtime information evaluated using `x`.

# Examples
```jldoctest
julia> x = (a = [1.0 2.0;], );

julia> vn = @varname(x.a[1, :])
x.a[1,:]

julia> AbstractPPL.concretize(vn, x)
x.a[1,:]

julia> vn = @varname(x.a[1, end][:]);

julia> AbstractPPL.concretize(vn, x)
x.a[1,2][:]
```
"""
concretize(vn::VarName, x) = VarName(vn, concretize(vn.indexing, x))

"""
    @varname(expr[, concretize])

A macro that returns an instance of [`VarName`](@ref) given a symbol or indexing expression `expr`.

If `concretize` is `true`, the resulting expression will be wrapped in a [`concretize`](@ref) call.
This is useful if you for example want to ensure that no `Setfield.DynamicLens` is used.

The `sym` value is taken from the actual variable name, and the index values are put appropriately
into the constructor (and resolved at runtime).

## Examples

```jldoctest
julia> @varname(x).indexing
()

julia> @varname(x[1]).indexing
(@lens _[1])

julia> @varname(x[:, 1]).indexing
(@lens _[Colon(), 1])

julia> @varname(x[:, 1][2]).indexing
(@lens _[Colon(), 1][2])

julia> @varname(x[1,2][1+5][45][3]).indexing
(@lens _[1, 2][6][45][3])
```

!!! compat "Julia 1.5"
    Using `begin` in an indexing expression to refer to the first index requires at least
    Julia 1.5.
"""
macro varname(expr::Union{Expr, Symbol}, concretize=false)
    return varname(expr, concretize)
end

varname(sym::Symbol, concretize=false) = :($(AbstractPPL.VarName){$(QuoteNode(sym))}())
function varname(expr::Expr, concretize=false)
    if Meta.isexpr(expr, :ref) || Meta.isexpr(expr, :.)
        sym = vsym(expr)
        # Convert `expr` into something `lensmacro` can parse.
        inds = Setfield.lensmacro(identity, replace_basesym(expr, :_))

        # TODO: Can we do better, i.e. only check if we have `DynamicLens`?
        return if concretize
            :($(AbstractPPL.concretize)($(AbstractPPL.VarName){$(QuoteNode(sym))}($inds), $(esc(sym))))
        else
            :($(AbstractPPL.VarName){$(QuoteNode(sym))}($inds))
        end
    else
        error("Malformed variable name $(expr)!")
    end
end


"""
    replace_basesym(expr, sub::Symbol)

Return `expr` with the base symbol replaced, e.g.
`:(x[1].a[end])` results in `:(\$(sub).[1].a[end])`

# Example
```jldoctest
julia> AbstractPPL.replace_basesym(:(x[1].a[end][:]), :_)
:(((_[1]).a[end])[:])

julia> AbstractPPL.replace_basesym(:(x), :_)
:x

julia> AbstractPPL.replace_basesym(:(1), :_)
1
```

"""
replace_basesym(x, sub::Symbol) = x
function replace_basesym(expr::Expr, sub::Symbol)
    # Recursively replace_basesym the first argument, until the first
    # argument is a `Symbol`, in which case we replace the first
    # argument with `:_` and return the expression.
    return if length(expr.args) > 0 && !(expr.args[1] isa Symbol)
        Expr(expr.head, replace_basesym(expr.args[1], sub), expr.args[2:end]...)
    else
        Expr(expr.head, sub, expr.args[2:end]...)
    end
end

"""
    @vsym(expr)

A macro that returns the variable symbol given the input variable expression `expr`.
For example, `@vsym x[1]` returns `:x`.

## Examples

```jldoctest
julia> @vsym x
:x

julia> @vsym x[1,1][2,3]
:x

julia> @vsym x[end]
:x
```
"""
macro vsym(expr::Union{Expr, Symbol})
    return QuoteNode(vsym(expr))
end

"""
    vsym(expr)

Return name part of the [`@varname`](@ref)-compatible expression `expr` as a symbol for input of the
[`VarName`](@ref) constructor."""
function vsym end

vsym(expr::Symbol) = expr
function vsym(expr::Expr)
    if Meta.isexpr(expr, :ref) || Meta.isexpr(expr, :.)
        return vsym(expr.args[1])
    else
        error("Malformed variable name $(expr)!")
    end
end

"""
    @vinds(expr)

Returns a tuple of tuples of the indices in `expr`.

## Examples

```jldoctest
julia> @vinds x
()

julia> @vinds x[1,1][2,3]
((1, 1), (2, 3))

julia> @vinds x[:,1][2,:]
((Colon(), 1), (2, Colon()))

julia> @vinds x[2:3,1][2,1:2]
((2:3, 1), (2, 1:2))

julia> @vinds x[2:3,2:3][[1,2],[1,2]]
((2:3, 2:3), ([1, 2], [1, 2]))
```

!!! compat "Julia 1.5"
    Using `begin` in an indexing expression to refer to the first index requires at least
    Julia 1.5.
"""
macro vinds(expr::Union{Expr, Symbol})
    return vinds(expr)
end


"""
    vinds(expr)

Return the indexing part of the [`@varname`](@ref)-compatible expression `expr` as an expression
suitable for input of the [`VarName`](@ref) constructor.

## Examples

```jldoctest
julia> vinds(:(x[end]))
:((((lastindex)(x),),))

julia> vinds(:(x[1, end]))
:(((1, (lastindex)(x, 2)),))
```
"""
function vinds end

vinds(expr::Symbol) = Expr(:tuple)
function vinds(expr::Expr)
    if Meta.isexpr(expr, :ref)
        ex = copy(expr)
        @static if VERSION < v"1.5.0-DEV.666"
            Base.replace_ref_end!(ex)
        else
            Base.replace_ref_begin_end!(ex)
        end
        last = Expr(:tuple, ex.args[2:end]...)
        init = vinds(ex.args[1]).args
        return Expr(:tuple, init..., last)
    else
        error("Mis-formed variable name $(expr)!")
    end
end
