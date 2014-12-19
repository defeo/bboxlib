module simplelanguage

export Program, NewVariable, FreeVariable, Variable, AccessTable, Affectation,
       add_instruction!, XOR, AND, OR, LShift, RShift, Add, Mul, Mod,
       Expression, VoidExpression, new_program, compile_python, NilExp, 
       set_entry!, set_output!, add_arg!, get_args, get_entry, get_output
       
############################ AST Description ###################################
abstract Instruction
abstract Expression

type NewVariable <: Instruction
    len::Integer
    _affected::Union(Integer, Nothing)
end
NewVariable(len::Integer) = NewVariable(len, Nothing())

type NilExp <: Expression end

immutable Variable <: Expression 
    ptr::NewVariable
end

type FreeVariable <: Instruction
    var::Variable
end

type Affectation <: Instruction
    dest::Variable
    src::Expression
end

const OperationList = (:XOR, :AND, :OR, :Add, :Mul, :Mod, :RShift, :LShift)
for T in OperationList 
    @eval type ($T) <: Expression
        left::Expression
        right::Expression
    end
end

type Const <: Expression
    ptr::BitVector
end

function Const(x::Integer)
    if x == 0
        return Const(BitVector(1))
    end
    t=BitVector(int(floor(log2(x)))+1)
    t.chunks[1] = x
    Const(t)
end
    
type AccessTable <: Expression
    table::Vector{BitVector}
    index::Expression
end

type Program
    ins::Vector{Instruction}
    input::Variable
    output::Expression
    args::Vector{Variable}
    function Program()
        p = new()
        p.ins = Instruction[]
        p.args = Variable[]
        p
    end
end

set_entry!(p::Program, v::Variable) =  (p.input = v)
set_output!(p::Program, v::Expression) = (p.output = v)
get_entry(p::Program) = p.input
get_output(p::Program) = p.output

add_arg!(p::Program, v::Variable) = push!(p.args, v)
get_args(p::Program) = p.args
add_instruction!(p::Program, i::Instruction) = push!(p.ins, i)



####################### Variables and Tables Management ########################

type MemoryManager
    variables::Array{Integer}
    tables::Dict{Vector{BitVector}, Integer}
    i_tables_max::Integer
    
    MemoryManager() = 
        new(Integer[], Dict{Vector{BitVector},Integer}(), 0::Integer)
end

function new_variable!(mm::MemoryManager, len::Integer)
    push!(mm.variables, len)
    size(mm.variables, 1)
end

function get_table_index!(mm::MemoryManager, t::Vector{BitVector})
    if haskey(mm.tables, t)
        mm.tables[t]
    else
        mm.i_tables_max += 1
        mm.tables[t] = mm.i_tables_max
        mm.i_tables_max
    end
end

#################### Python Compilation ########################################

compile_python(p::Program) = compile_python([p])

function compile_python(progs::Vector{Program})
    mm = MemoryManager()
    code = compile_python!(progs[1], mm)    
    for i in 2:size(progs,1)
        code *= compile_python!(progs[i], mm, get_output(progs[i-1]))
    end
    args_list = ""#join([compile_python!(v, mm) for v in get_args(p)])
    res = "def f("compile_python!(get_entry(progs[1]), mm)","*args_list*"):"code
    res *= "\n\treturn "compile_python!(get_output(progs[end]),mm)
    tables = ""
    for (t,i) in mm.tables
        tables *= "t"*string(i)*"=["
        tables *= join(["0x"hex(a) for a in t], ",")
        tables *= "]\n"
    end
    tables*"\n"*res, mm
end


function compile_python!(p::Program, mm::MemoryManager)
    code = ""
    for ins in p.ins
        new_line = compile_python!(ins, mm)
        if new_line != ""
            code *=  "\n\t"*new_line * ""
        end
    end
    code
end

function compile_python!(p::Program, mm::MemoryManager, exp_in::Expression)
    code = compile_python!(p, mm)
    init = "\n\t"*compile_python!(get_entry(p), mm)*
                      "="*compile_python!(exp_in, mm)
    init*code
end

function compile_python!(x::Variable, mm::MemoryManager)
    x.ptr._affected != Nothing() || error("variable not initialized")
    "v"string(x.ptr._affected)
end
function compile_python!(x::NewVariable, mm::MemoryManager)
    var = new_variable!(mm, x.len)
    x._affected = var
    return ""
end

compile_python!(x::Const, mm::MemoryManager) = "0x"hex(x.ptr)

compile_python!(x::Affectation, mm::MemoryManager) =
    "v"string(x.dest.ptr._affected)"="compile_python!(x.src, mm)

compile_python!(x::AccessTable, mm::MemoryManager) =
    "t"string(get_table_index!(mm, x.table))"["compile_python!(x.index, mm)"]"

for (T, Op) in ( (AND, "&"), (XOR, "^"), (OR, "|"), (LShift, "<<"),
                (RShift, ">>"), (Add, "+"), (Mul, "*"), (Mod, "%") )
    @ eval compile_python!(x::($T), mm::MemoryManager) =
        "("compile_python!(x.left, mm) * ($Op) * compile_python!(x.right, mm)")"
end    
 
import Base.hex
    
function hex(x::BitVector)
    res = hex(x.chunks[end])
    for i in size(x.chunks,1)-1:-1:1
        h = hex(x.chunks[i])
        res*= "0"^(16-length(h)) * h
    end
    res
end

#p = Instruction[]
#ins = NewVariable(5)
#v= Variable(ins)

#add_instruction!(p,ins)
#c = Const(5)
#c = AND(c , c)
#insAff = Affectation(v, c)
#add_instruction!(p, insAff)
#println(p)
#println(compile_python(p))
end#module
