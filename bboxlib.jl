import Base.string
import Base.convert
import Base.size

abstract BoolFunc{In, Out}

size{In, Out}(x::BoolFunc{In, Out}) = (In, Out)
sizeIn{In}(x::BoolFunc{In}) = In
sizeOut{In, Out}(x::BoolFunc{In, Out}) = Out

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

type Joker end

type Seq{In, Out} <: BoolFunc{In, Out} 
    seq::Vector
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

type Perm{In} <: BoolFunc{In, In}
    perm::Array{Integer, 1}
    function Perm(x) 
        is_permutation(x) || error("not a permutation")
        new(convert(Array{Integer,1},x))
    end
end
Perm(x) = Perm{size(x,1)}(x)

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
type BinOp{In} <: BoolFunc{In, In}
    op::Char
    func::BoolOut{In}
end
BinOp(op::Char, func::BoolFunc) = BinOp{sizeOut(func)}(op, func)
XOR(func::BoolFunc) = BinOp('^', func)
AddMod(func::BoolFunc) = BinOp('+', func)
MulMod(func::BoolFunc) = BinOp('*', func)

function convert{In, Out}(::Type{BoolFunc{In, Out}}, s::Slice{Joker, Out})
    s.term > In && error("unable to convert Slice: invalid slice bounds")
    Slice{In, Out}(s.start, s.term)
end

function convert{In, Out}(::Type{BoolFunc{In, Out}}, s::Seq{Joker, Out})
    first = s.seq[1]
    firs_new = convert(BoolFunc{In, sizeOut(first)}, first)
    seq_new = [firs_new ; s.seq[2:end]]
    Seq{In, Out}(seq_new)
end  

function convert{In, Out}(::Type{BoolFunc{In, Out}}, c::Cat{Joker, Out})
    funcs = [convert(BoolFunc{In, sizeOut(s)}, s) for s in c.funcs]
    Cat{In, Out}(funcs)
end        

>>{In, Out, T}(x::BoolFunc{In, T}, y::BoolFunc{T, Out}) = 
    Seq{In, Out}(BoolFunc[x, y])

>>{In, Out, T}(x::Seq{In, T}, y::Seq{T, Out}) = 
    Seq{In, Out}(vcat(x.seq, y.seq))

>>{In, Out, T}(x::Seq{In, T}, y::BoolFunc{T, Out}) = 
    Seq{In, Out}(BoolFunc[x.seq...; y])

>>{In, Out, T}(x::BoolFunc{In, T}, y::Seq{T, Out}) = 
    Seq{In, Out}(BoolFunc[x; y.seq...])

for T2 in (Seq, BoolFunc)
    for T1 in (Seq, BoolFunc)
        @eval >>{In, Out}(x::($T1){In,Joker}, y::($T2){Joker,Out})=
            error("output size is jokered... how did you do that?")
        
        @eval >>{In, Out, T}(x::($T1){In, T}, y::($T2){Joker, Out}) =  
            x >> convert(($T2){T, Out}, y)
        
    end
end

<<(x::BoolFunc, y::BoolFunc) = >>(y,x)

+{In, O1, O2}(x::BoolFunc{In, O1}, y::BoolFunc{In, O2}) =
    Cat{In, O1+O2}(BoolFunc[x; y])

+{In, O1, O2}(x::Cat{In, O1}, y::Cat{In, O2}) =
    Cat{In, O1+O2}(vcat(x.funcs, y.funcs))
    
+{In, O1, O2}(x::Cat{In, O1}, y::BoolFunc{In, O2}) =
    Cat{In, O1+O2}(BoolFunc[x.funcs...; y])

+{In, O1, O2}(x::BoolFunc{In, O1}, y::Cat{In, O2}) =
    Cat{In, O1+O2}(BoolFunc[x; y.funcs...])

string_as_list(x) = "["join([string(e) for e in x], ", ")"]"

string(x::Seq) = string_as_list(x.seq) 
string(x::Cat) = join([string(e) for e in x.funcs], " ++ ")
string(x::Perm) = "perm "string_as_list(x.perm)
string(x::SBox) = "sbox [...]"
string(x::Slice) = "[$(x.start):$(x.term)]"

#p=Perm([1, 2, 3, 4, 6, 7, 8, 5, 11, 12, 9, 10, 16, 13, 14, 15])
#println(string(p))
#println(string(p<<p))
#println(string(p+p))

#trans = (
#    Slice(1,8) + Slice(33,40) + Slice(65,72) + Slice(97,104)
#    + Slice(9,16) + Slice(41,48) + Slice(73,80) + Slice(105,112)
#    + Slice(17,24) + Slice(49,56) + Slice(81,88) + Slice(113,120)
#    + Slice(25,32) + Slice(57,64) + Slice(89,96) + Slice(121,128)
#)
#1,8,9,16,17,24,25,32,33,40
#p = Perm([1:128...])

##println(trans)
#b = trans >> p
#println(b)
#a = p >> trans
#print(a)	

# The two following lines must throw an error if uncomment:
#sb = SBox([[BitVector(5) for i in 1:15], [BitVector(6) for i in 1:1]]) #Bad output size
#sb = SBox([BitVector(5) for i in 1:10]) #Bad input size

# The following lines must work correctly
sb = SBox([BitVector(5) for i in 1:16]) # input size: 4 (since 16 = 2^4)  
s = Slice(1, 8)
s2 = Slice(1, 2)
xor = XOR(Const(trues(4)))
println(xor>>sb)
println()
println(AddMod(xor>> sb) >> (Slice(1,2) + Slice(3,4)) )
println()
println(((s >> Perm([1:8...])) + s) )
println( Slice(1,16) >> ((s >> Perm([1:8...])) + s) )
