## matrix class stuff
## Work with Array{Sym}, not python array objects, as possible
## requires conversion from SymMatrix -> Array{Sym} in outputs, as appropriate


## covert back to Array{Sym}
subs(ex::Array{Sym}, args...; kwargs...) = Sym[subs(u, args...; kwargs...) for u in ex]

getindex(s::SymMatrix, i::Integer...) = get(PyObject(s), Sym, ntuple(k -> i[k]-1, length(i)))
getindex(s::SymMatrix, i::Integer) = get(PyObject(s), Sym, map(x->x-1, ind2sub(size(s), i)))
getindex(s::SymMatrix, i::Symbol) = PyObject(s)[i]
getindex(s::Array{Sym}, i::Symbol) = getindex(convert(SymMatrix,s),i) # diagonalize..

## size
function size(x::SymMatrix)
    a = x[:shape]               # a PyObject tuple
    isa(a, PyObject) ? (a[:__getitem__](0), a[:__getitem__](1)) : a
end

function size(x::SymMatrix, dim::Integer)
    if dim <= 2 && pyisinstance(PyObject(x), matrixtype)
        return x[:shape][dim]
    else
        return 1
    end
end

## we want our matrices to be arrays of Sym objects, not symbolic matrices
## so that julia manages them
## it is convenient (for printing, say) to convert to a sympy matrix
convert(::Type{SymMatrix}, a::Array{Sym}) = sympy["Matrix"](a)

convert(::Type{Sym}, a::Array{Sym}) = sympy["Matrix"](a)
function convert(::Type{Array{Sym}}, a::SymMatrix)
    sz = size(a)
    ndims = length(sz)
    if ndims == 0
        a
    elseif ndims == 1
        Sym[a[i] for i in 1:length(a)]
    elseif ndims == 2
        Sym[a[i,j] for i in 1:size(a)[1], j in 1:size(a)[2]]
    else
        ## need something else for arrays... XXX -- can't linear index a
        b = Sym[a[i] for i in 1:length(a)]
        reshape(b, sz)
    end
end


## linear algebra functions that are methods of sympy.Matrix
## return a "scalar"
for meth in (:condition_number,
           )

    cmd = "x." * string(meth) * "()"
    meth_name=string(meth)
    @eval begin
           @doc """
`$($meth_name)`: a SymPy function.
The SymPy documentation can be found through: http://docs.sympy.org/latest/search.html?q=$($meth_name)
""" ->
        ($meth)(a::SymMatrix) = pycall(a[($cmd)], Sym, x)
        ($meth)(a::Matrix{Sym}) = ($meth)(convert(SymMatrix, a))
    end
    eval(Expr(:export, meth))
end

## can be any dimension
for meth in (:norm,
             )
    meth_name = string(meth)
    @eval begin
        @doc """
`$($meth_name)`: a SymPy function.
The SymPy documentation can be found through: http://docs.sympy.org/latest/search.html?q=$($meth_name)
""" ->
        ($meth)(a::SymMatrix, args...; kwargs...) = call_matrix_meth(a, $meth_name, args...;kwargs...)
        ($meth)(a::Array{Sym}, args...; kwargs...) = ($meth)(convert(SymMatrix, a), args...;kwargs...)
    end
    eval(Expr(:export, meth))
end

for meth in (
           :has,
           )
    meth_name = string(meth)
    @eval begin
      @doc """
`$($meth_name)`: a SymPy function.
The SymPy documentation can be found through: http://docs.sympy.org/latest/search.html?q=$($meth_name)
""" ->
        ($meth)(a::SymMatrix, args...; kwargs...) = call_matrix_meth(a, $meth_name, args...;kwargs...)
        ($meth)(a::Matrix{Sym}, args...; kwargs...) = ($meth)(convert(SymMatrix, a), args...;kwargs...)
    end
    eval(Expr(:export, meth))
end

## don't define inv for Matrix{Sym}, we use base inv there
## gives similar -- but different answers:
## e.g. a = [x 1; 1 x]; inv(a) and `inv(convert(SymMatrix,a))` have different simplification
inverse(ex::Matrix{Sym}) = call_matrix_meth(convert(SymMatrix, ex),:inv)
inverse(ex::SymMatrix) = call_matrix_meth(ex, :inv)
Base.inv(ex::SymMatrix) = inverse(ex)
export inverse


# and overload det for SymMatrix
Base.det(a::SymMatrix) = call_matrix_meth(a, :det)


## But
## is_symmetric <-> issym
## istriu, istril,
for meth in  (:is_anti_symmetric, :is_diagonal, :is_diagonalizable,:is_nilpotent,
                :is_symbolic, :is_symmetric)

    meth_name = string(meth)
    @eval begin
      @doc """
`$($meth_name)`: a SymPy function.
The SymPy documentation can be found through: http://docs.sympy.org/latest/search.html?q=$($meth_name)
""" ->
        ($meth)(ex::SymMatrix, args...; kwargs...) = ex[@compat(Symbol($meth_name))]()
        ($meth)(ex::Matrix{Sym}, args...; kwargs...) =  ($meth)(convert(SymMatrix, ex), args...;kwargs...)
    end
    eval(Expr(:export, meth))
end


## methods called as properties

## is_upper <-> itriu
## is_lower <-> istril
matrix_operators = (:H, :C,
                    :is_lower, :is_lower_hessenberg, :is_square, :is_upper,  :is_upper_hessenberg, :is_zero
)

for meth in matrix_operators
     meth_name = string(meth)
    @eval begin
      @doc """
`$($meth_name)`: a SymPy function.
The SymPy documentation can be found through: http://docs.sympy.org/latest/search.html?q=$($meth_name)
""" ->
        ($meth)(ex::SymMatrix, args...; kwargs...) = ex[@compat(Symbol($meth_name))]
        ($meth)(ex::Matrix{Sym}, args...; kwargs...) =  ($meth)(convert(SymMatrix, ex), args...;kwargs...)
    end
    eval(Expr(:export, meth))
end



## These take a matrix, return a container of symmatrices. Here we convert these to arrays of sym
## Could use
## - qr generically instead of QRdecomposition
## - lu instead of
## - chol will call cholesky
map_matrix_methods = (:LDLsolve,
                      :LDLdecomposition, :LDLdecompositionFF,
                      :LUdecomposition_Simple,
                      :LUsolve,
                      :QRdecomposition, :QRsolve,
                      :adjoint, :adjugate,
                      :cholesky, :cholesky_solve, :cofactor, :conjugate,
                      :diagaonal_solve, :diagonalize, :dual,
                      :expand,
                      :integrate,
                      :inverse_ADJ, :inverse_GE, :inverse_LU,
                      :jordan_cells, :jordan_form,
                      :limit,
                      :lower_triangular_solve,
                      :minorEntry, :minorMatrix,
                      :normalized, :nullspace,
                      :permuteBkwd, :permuteFwd,
                      :print_nonzero,
                      :singular_values,
                      :upper_triangular_solve,
                      :vech
)

for meth in map_matrix_methods
    meth_name = string(meth)
    @eval begin
      @doc """
`$($meth_name)`: a SymPy function.
The SymPy documentation can be found through: http://docs.sympy.org/latest/search.html?q=$($meth_name)
""" ->
        ($meth)(ex::SymMatrix, args...; kwargs...) = call_matrix_meth(ex, @compat(Symbol($meth_name)), args...; kwargs...)
        ($meth)(ex::Matrix{Sym}, args...; kwargs...) =  ($meth)(convert(SymMatrix, ex), args...;kwargs...)
    end
    eval(Expr(:export, meth))
end


### Some special functions
Base.chol(a::Matrix{Sym}) = cholesky(a)

expm(a::SymMatrix) = a[:exp]()
expm(ex::Matrix{Sym}) = convert(Array{Sym}, expm(convert(SymMatrix, ex)))


Base.conj(a::SymMatrix) = conjugate(a)
Base.conj(a::Sym) = conjugate(a)


## :eigenvals, returns {val => mult, val=> mult}
## we return an array of eigen values, as eigvals does
function eigvals(a::SymMatrix)
    ## this is a hack, as  d = a[:eigenvals]() may not convert to a Julia dict (Ubuntu...)
    ds = call_matrix_meth(a, :eigenvects)
    [d[1] for d in ds]
end
eigvals(a::Matrix{Sym}) = eigvals(convert(SymMatrix, a))

## :eigenvects ## returns list of triples (eigenval, multiplicity, basis).
"""

The `eigvecs` function returns a list of triples (eigenval, multiplicity, basis) for an `Matrix{Sym}`.

"""
function eigvecs(a::SymMatrix)
    ds =  call_matrix_meth(a, :eigenvects)
    hcat([hcat([convert(Array{Sym}, v) for v in d[3]]...) for d in ds]...)
end
eigvecs(a::Matrix{Sym}) = eigvecs(convert(SymMatrix, a))

## Take any matrix and return reduced row-echelon form and indices of pivot vars
## To simplify elements before finding nonzero pivots set simplified=True
## We return only the rref form -- not the pivot vars.
"""

Return reduced row echelon form. This function does not return the
pivot variables generated by SymPy. For those, something like `m,
pivots = convert(SymMatrix, a)[:rref]()` would work.

As `rref` is no longer in base, as of v"0.4.0", we extend the
interface to `Matrix{Int}` and `Matrix{Rational}`. The return value
will be `Matrix{Int}` if possible, otherwise a matrix of type
rational.

"""
function rref(a::SymMatrix)
  d = a[:rref]()
  convert(Array{Sym}, d[1]) ## return Array{Sym}, not SymMatrix
end
rref(a::Matrix{Sym}; kwargs...) =rref(convert(SymMatrix, a); kwargs...)
# extend for wider use:
rref{T <: Integer}(a::Matrix{T}) = N(rref(convert(Matrix{Sym}, a)))
rref{T <: Integer}(a::Matrix{Rational{T}}) = N(rref(convert(Matrix{Sym}, a)))

## call with a (A,b), return array
for fn in (:cross,
           )
    cmd = "x." * string(fn) * "()"
    meth_name = string(fn)
    @eval begin
      @doc """
`$($meth_name)`: a SymPy function.
The SymPy documentation can be found through: http://docs.sympy.org/latest/search.html?q=$($meth_name)
""" ->
        ($fn)(A::SymMatrix, b::Sym) = object_meth(A, fn, convert(SymMatrix,b))
        ($fn)(A::Array{Sym, 2}, b::Vector{Sym}) = $(fn)(convert(SymMatrix,A), b)
    end
end


### Higher dimensional derivatives

## For gradient we have [diff(ex,var) for var in free_symbols(ex)]... but order is of importance...


"""

Jacobian of a symbolic matrix

Example:

```
rho, phi = symbols("rho, phi")
M = [rho*cos(phi), rho*sin(phi), rho^2]
Y = [rho, phi]
jacobian(M, Y)
```
"""
function jacobian(x::Array{Sym}, y::Array{Sym})
    X = convert(SymMatrix, x)
    Y = convert(SymMatrix, y)
    call_matrix_meth(X, :jacobian, Y)
end



"""

Find Hessian of a symbolic expression

Example:
```
x, y = symbols("x y")
f = x^2 - 2x*y
hessian(f, [x,y])
```
"""
function hessian(f::Sym, x::Vector{Sym})
    out = sympy_meth(:hessian, f, x)
    convert(SymMatrix, out) |> u -> convert(Array{Sym}, u)
end
hessian(ex::Sym) = hessian(ex, free_symbols(ex))
