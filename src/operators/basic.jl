# EXPORTS
export AbstractOperator, ScalarOperator, VectorOperator, MatrixOperator
export id, Id, ID
export grad, Grad, GRAD
export div, Div, DIV

abstract AbstractOperator

abstract ScalarOperator <: AbstractOperator
abstract VectorOperator <: AbstractOperator
abstract MatrixOperator <: AbstractOperator

#---------------#
# Type Operator #
#---------------#
type Operator{T<:AbstractOperator} <: AbstractOperator
    fes :: FESpace
    discrete :: Nullable{Vector}
end

# Outer Constructors
# -------------------
Operator{T<:AbstractOperator}(::Type{T}, fes::FESpace) = Operator{T}(fes, Nullable{Vector}())

# Associated Methods
# -------------------
"""

    space(op::AbstractOperator)

  Return the finite element space of the operator `op`.
"""
fespace(op::Operator) = getfield(op, :fes)

#-------------------------#
# Identity Operator Types #
#-------------------------#
type id <: ScalarOperator end
type Id <: VectorOperator end
type ID <: MatrixOperator end

function evaluate{T<:AbstractFloat}(::Operator{id}, points::AbstractArray{T,2})
    basis = evalBasis(element(fespace(op)), points, 0)
    @assert ndims(basis) == 3 && size(basis, 3) == 1 # nB x nP x 1
    return basis
end

function evaluate{T<:AbstractFloat}(op::Operator{Id}, points::AbstractArray{T,2})
    Basis = evalBasis(element(fespace(op)), points, 0)
    @assert ndims(Basis) == 3 # nB x nP x nD
    return Basis
end

function evaluate{T<:AbstractFloat}(op::Operator{ID}, points::AbstractArray{T,2})
    BASIS = evalBasis(element(fespace(op)), points, 0)
    @assert ndims(BASIS) == 4 # nB x nP x nD x nD
    return BASIS
end

#-------------------------#
# Gradient Operator Types #
#-------------------------#
type grad <: ScalarOperator end
type Grad <: VectorOperator end
type GRAD <: MatrixOperator end

function evaluate{T<:AbstractFloat}(op::Operator{Grad}, points::AbstractArray{T,2})
    dBasis = evalBasis(element(fespace(op)), points, 1)
    invdPhi = evalJacobianInverse(mesh(fespace(op)), points)

    nB, nP, nC, nD = size(dBasis)
    nE, nP, nW, nD = size(invphi)
    @assert nC == 1

    G = zeros(T, nE, nB, nP, nD)
    fill_Grad!(G, dBasis, invdPhi)

    return G
end

function fill_Grad!{T<:AbstractFloat}(G::Array{T,4}, dBasis::Array{T,4}, invdPhi::Array{T,4})
    for id = 1:size(dBasis, 4)
        for iw = 1:size(invdPhi, 3)
            for ip = 1:size(dBasis, 2)
                for ib = 1:size(dBasis, 1)
                    for ie = 1:size(invdPhi, 1)
                        G[ie,ib,ip,id] += invdPhi[ie,ip,iw,id] * dBasis[ib,ip,1,id]
                    end
                end
            end
        end
    end
    return nothing
end

#---------------------------#
# Divergence Operator Types #
#---------------------------#
type div <: ScalarOperator end
type Div <: VectorOperator end
type DIV <: MatrixOperator end

function evaluate{T<:AbstractFloat}(op::Operator{div}, points::AbstractArray{T,2})
    dBasis = evalBasis(element(fespace(op)), points, 1)
    invdPhi = evalJacobianInverse(mesh(fespace(op)), points)

    nB, nP, nC, nD = size(dBasis)
    nE, nP, nW, nD = size(invphi)

    D = zeros(T, nE, nB, nP)

    if nC == 1
        fill_div!(D, view(dBasis, :, :, ones(Int, nD), :), invdPhi)
    else
        @assert nC == nD
        fill_div!(D, dBasis, invdPhi)
    end

    return D
end

function fill_div!{T<:AbstractFloat}(D::Array{T,3}, dBasis::AbstractArray{T,4}, invdPhi::Array{T,4})
    for id = 1:size(dBasis, 4)
        for iw = 1:size(invdPhi, 3)
            for ip = 1:size(dBasis, 2)
                for ib = 1:size(dBasis, 1)
                    for ie = 1:size(invdPhi, 1)
                        D[ie,ib,ip] += invdPhi[ie,ip,iw,id] * dBasis[ib,ip,id,id]
                    end
                end
            end
        end
    end
    return nothing
end

