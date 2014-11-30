module bboxlib

import Base.string
import Base.convert
import Base.size
import Base.repr


export <<, >>, +, Slice, SBox, Perm, PermBytes, UXOR, UMulMod, UAddMod, BXOR,
    BMulMod, BAddMod, Const, Input, Map, is_closed, inputs


########################### TYPES DEFINITIONS ################################## 

abstract BoolFunc{In, Out}

size{In, Out}(x::BoolFunc{In, Out}) = (In, Out)
sizeIn{In}(x::BoolFunc{In}) = In
sizeOut{In, Out}(x::BoolFunc{In, Out}) = Out

type Joker end

type Seq{In, Out} <: BoolFunc{In, Out} 
    funcs::Vector
end

type Cat{In, Out} <: BoolFunc{In, Out} 
    funcs::Vector
end

type Slice{In, Out} <: BoolFunc{In, Out}
    start::Integer
    term::Integer
    function Slice(start, term) 
        term >= start > 0 || error("invalid slice bounds")
        new(start, term)
    end
end
Slice(start, term) = Slice{Joker, term - start + 1}(start, term)


type SBox{In, Out} <: BoolFunc{In, Out}
    table::Array{BitVector,1}
    function SBox(x)
        n = size(x, 1)
        n == 0 && error("SBox is empty")

        l = size(x[1], 1)
        for i in 2:n
            @inbounds l == size(x[i], 1) || 
            error("all the outputs of the SBox must have the same size")
        end
        new(x)
    end
end
SBox(table::Array{BitVector,1}) =
    SBox{log2_exact(size(table, 1)), size(table[1], 1)}(table)

type Const{Out} <: BoolFunc{0}{Out}
    val::BitArray{1}
end
Const(val::BitArray{1}) = Const{size(val, 1)}(val)

typealias BoolOut{Out, In} BoolFunc{In, Out}
abstract UnOp{In} <: BoolFunc{In, In}

const UnOpList = (:UXOR, :UAddMod, :UMulMod)
const UnOpSymbs = ("^",  "+",      "*")

for T in UnOpList
    @eval type ($T){In} <: UnOp{In} ; func::BoolOut{In} end
    @eval ($T)(func::BoolFunc) = ($T){sizeOut(func)}(func)
end

abstract BinOp{In, Out} <: BoolFunc{In, Out}

const BinOpList = (:BXOR, :BAddMod, :BMulMod)
const BinOpSymbs = ("^",  "+",      "*")

for T in BinOpList
    @eval type ($T){In, Out} <: BinOp{In, Out} end
    @eval ($T)(s) = ($T){Joker, s}()
end 

type Input{Out} <: BoolFunc{0, Out}
    name
end
Input(s::Integer, name)=Input{s}(name)
Input(s::Integer) = Input(s,"")

############################### SEQUENCING #####################################
>>{In, Out, T}(x::BoolFunc{In, T}, y::BoolFunc{T, Out}) = 
    Seq{In, Out}(BoolFunc[x, y])

>>{In, Out, T}(x::Seq{In, T}, y::Seq{T, Out}) = 
    Seq{In, Out}(vcat(x.funcs, y.funcs))

>>{In, Out, T}(x::Seq{In, T}, y::BoolFunc{T, Out}) = 
    Seq{In, Out}(BoolFunc[x.funcs...; y])

>>{In, Out, T}(x::BoolFunc{In, T}, y::Seq{T, Out}) = 
    Seq{In, Out}(BoolFunc[x; y.funcs...])

for T2 in (Seq, BoolFunc)
    for T1 in (Seq, BoolFunc)
        @eval >>{In, Out}(x::($T1){In,Joker}, y::($T2){Joker,Out})=
            error("output size is jokered... how did you do that?")
        
        @eval >>{In, Out, T}(x::($T1){In, T}, y::($T2){Joker, Out}) =  
            x >> convert(BoolFunc{T, Out}, y)
        
    end
end

<<(x::BoolFunc, y::BoolFunc) = >>(y,x)

########################### CONCATENATION ######################################

+{In, O1, O2}(x::BoolFunc{In, O1}, y::BoolFunc{In, O2}) =
    Cat{In, O1+O2}(BoolFunc[x; y])

+{In, O1, O2}(x::Cat{In, O1}, y::Cat{In, O2}) =
    Cat{In, O1+O2}(vcat(x.funcs, y.funcs))
    
+{In, O1, O2}(x::Cat{In, O1}, y::BoolFunc{In, O2}) =
    Cat{In, O1+O2}(BoolFunc[x.funcs...; y])

+{In, O1, O2}(x::BoolFunc{In, O1}, y::Cat{In, O2}) =
    Cat{In, O1+O2}(BoolFunc[x; y.funcs...])
    
####################### CONVERSION #############################################

function convert{In, Out}(::Type{BoolFunc{In, Out}}, s::Slice{Joker, Out})
    s.term > In && error("unable to convert Slice: invalid slice bounds")
    Slice{In, Out}(s.start, s.term)
end

for T in BinOpList
    @eval function convert{In, Out}(::Type{BoolFunc{In, Out}}, s::($T){Joker, Out})
        In % Out == 0 || error("BinOp in size must be a multiple of its out size")
        $(T){In, Out}()
    end
end

function convert{In, Out}(::Type{BoolFunc{In, Out}}, s::Seq{Joker, Out})
    first = s.funcs[1]
    firs_new = convert(BoolFunc{In, sizeOut(first)}, first)
    funcs_new = [firs_new ; s.funcs[2:end]]
    Seq{In, Out}(funcs_new)
end  

function convert{In, Out}(::Type{BoolFunc{In, Out}}, c::Cat{Joker, Out})
    funcs = [convert(BoolFunc{In, sizeOut(s)}, s) for s in c.funcs]
    Cat{In, Out}(funcs)
end

string_as_list(x) = "["join([string(e) for e in x], ", ")"]"

string(x::Seq) = string_as_list(x.funcs) 
string(x::Cat) = join([string(e) for e in x.funcs], " ++ ")
#string(x::Perm) = "perm "string_as_list(x.perm)
string(x::SBox) = "sbox [...]"
string(x::Slice) = "[$(x.start):$(x.term)]"

for (T1, T2, symb) in zip(UnOpList, BinOpList, UnOpSymbs)
    @eval string(x::($T1)) = string(x.func)*string(($symb))
    @eval string(x::($T2)) = string(($symb))"Red"
end


############################### CONSISTANCE CHECKING ###########################

# If the entrance bits of x is plugged, is x close ?
# (i.e. there is no free entrance bits in all the structure x)
_is_closed(x::BoolFunc) = true
_is_closed(x::UnOp) = is_closed(x.func)
_is_closed(x::Seq) = all([_is_closed(s) for s in x.funcs[2:end]])
_is_closed(x::Cat) = all([_is_closed(s) for s in x.funcs])

# All the entrances of x are they plugged ?
is_closed(x::BoolFunc) = false
is_closed(x::Const) = true
is_closed(x::Input) = true
is_closed(x::Seq) = is_closed(x.funcs[1]) && _is_closed(x)
is_closed(x::Cat) = all([is_closed(s) for s in x.funcs])

_inputs(x::BoolFunc, acc) = acc
_inputs(x::Input, acc) = push!(acc, x)
_inputs(x::UnOp, acc) = _inputs_list(x.func, acc)
for T in (Seq, Cat)
    @eval function _inputs_list(x::($T), acc)
        for f in x.funcs
            _inputs_list(f, acc)
        end
        acc
    end
end
inputs(x::BoolFunc) = _inputs(x,Set{Input}())


######################## JULIA - EVALUATION ####################################
typealias BV BitVector
_eval(x::Const, ctxt, in_val::BV) = x.val
_eval(x::Input, ctxt, in_val::BV) = ctxt[x.name]
_eval(x::SBox, ctxt, in_val::BV) = x.table[in_val.chunks[1]+1]
_eval(x::Slice, ctxt, in_val::BV) = in_val[x.start:x.term]

    #Seq and Cat
function _eval(x::Seq, ctxt, in_val::BV)
    for f in x.funcs
        in_val = _eval(f, ctxt, in_val)
    end
    in_val
end

function _eval(x::Cat, ctxt, in_val::BV)
    t = BV(0)
    for f in x.funcs
        append!(t, _eval(f, ctxt, in_val))
    end
    t
end
    # UnOp
_eval(x::UXOR, ctxt, in_val::BV) = _eval(x.func, ctxt, BV(0)) $ in_val
for (T, op) in ((UAddMod, +), (UMulMod, *))
    @eval function _eval(x::($T), ctxt, in_val::BV)
        b = _eval(x.func, ctxt, BV(0)).chunks[1]
        a = in_val.chunks[1]
        out_size = sizeOut(x)
        t = BV(out_size)
        out_val = ($op)(a, b) % 2^out_size
        t.chunks[1] = out_val
        t
    end
end

    # BinOp
function _eval(x::BXOR, ctxt, in_val::BV) 
    in_size, out_size = size(x)
    n = div(in_size, out_size)
    t = in_val[1:end/n]
    for i in 1:(n-1)
        t $= in_val[end/n*i+1:end/n*(i+1)]
    end
    t
end

for (T, op) in ((BAddMod, +), (BMulMod, *))
    @eval function _eval(x::($T), ctxt, in_val::BV)
        in_size, out_size = size(x)
        n = div(in_size, out_size)
        a = in_val[1:end/n].chuns[1]
        for i in 1:(n-1)
            a = ($op) (a, in_val[end/n*i+1:end/n*(i+1)]) % 2^out_size
        end
        t = BV(out_size)
        t.chunks[1] = out_val
        t
    end
end

#################### CONVENIENCE FUNCTION ######################################

Perm(perm::Vector) = Perm(1, perm)
PermBytes(perm::Vector) = Perm(8, perm)
function Perm(block::Integer, perm::Vector) 
    is_permutation(perm) || error("not a permutation")
    p = perm
    n = block * size(perm, 1)
    funcs =  BoolFunc[convert(BoolFunc{n,block}, Slice(block*(p[i]-1)+1, block*p[i]))
                        for i in 1:size(perm,1)]
    Cat{n, n}(funcs)
end


function Map(func::BoolFunc, out_size)
    n = sizeOut(func)
    out_size % n == 0 || 
        error("out size of Map must be a multiple of the out size of the function")
    sum( [Slice(n*(i-1)+1, n*i) >> func for i in 1:div(out_size,n)] )
end

########################## HELPER FUNCTIONS ####################################

function is_permutation(p)
    n = size(p ,1)
    t = falses(n)
    for i = 1:n
        e = p[i]
        if e < 1 || e > n || t[e]
            return false
        end
        t[e] = true
    end
    return true
end

function log2_exact(n::Integer)
    p = 0
    while n > 1
        bool(n & 1) && error("not a power of 2")
        p += 1
        n >>= 1
    end
    p
end

end # end module
