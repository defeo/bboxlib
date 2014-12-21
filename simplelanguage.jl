module simplelanguage

import Base.convert

export Program, NewVariable, NewArg, FreeVariable, Variable, AccessTable, 
       Affectation, add_instruction!, XOR, AND, OR, LShift, RShift, Add, Mul, 
       Mod, Expression, VoidExpression, new_program, compile_python, 
       compile_java, NilExp, set_entry!, set_output!, add_arg!, get_args, 
       get_entry, get_output
       
############################ AST Description ###################################
abstract Instruction
abstract Expression

for T in (:NewVariable, :NewArg)
    @eval type ($T) <: Instruction
        len::Int
        _affected::Union(Int, Nothing)
    end
    @eval ($T)(len::Int) = ($T)(len, Nothing())
end

type NilExp <: Expression end

immutable Variable <: Expression 
    ptr::Union(NewVariable, NewArg)
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

function Const(x::Int)
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

    function Program()
        p = new()
        p.ins = Instruction[]
        p
    end
end

set_entry!(p::Program, v::Variable) =  (p.input = v)
set_output!(p::Program, v::Expression) = (p.output = v)
get_entry(p::Program) = p.input
get_output(p::Program) = p.output

add_instruction!(p::Program, i::Instruction) = push!(p.ins, i)

####################### Variables and Tables Management ########################

type MemoryManager
    variables::Array{Int} # the size of each variable (the sizes are not currently used)
    args::Array{Int} # the indices of the variables used for the args
    i_args_max::Int
    tables::Dict{Vector{BitVector}, Int}
    i_tables_max::Int
    
    MemoryManager() = 
        new(Int[], Int[], 0, Dict{Vector{BitVector},Int}(), 0::Int)
end

function new_variable!(mm::MemoryManager, len::Int)
    push!(mm.variables, len)
    size(mm.variables, 1)
end

function new_arg!(mm::MemoryManager, len::Int)
    mm.i_args_max +=1
    if mm.i_args_max > size(mm.args, 1)
       push!(mm.args, new_variable!(mm, len))
    end
    mm.args[mm.i_args_max]
end

flush_args(mm::MemoryManager) = mm.i_args_max = 0

get_args(mm::MemoryManager) = mm.args
get_variables(mm::MemoryManager) = 1:size(mm.variables,1)

function get_table_index!(mm::MemoryManager, t::Vector{BitVector})
    if haskey(mm.tables, t)
        mm.tables[t]
    else
        mm.i_tables_max += 1
        mm.tables[t] = mm.i_tables_max
        mm.i_tables_max
    end
end

############################ Python Compilation ################################

compile_python(p::Program) = compile_python([p])

function compile_python(progs::Vector{Program}, name::String)
    mm = MemoryManager()
    code = compile_python!(progs[1], mm)    
    for i in 2:size(progs,1)
        flush_args(mm)
        code *= compile_python!(progs[i], mm, get_output(progs[i-1]))
    end
    returned_value = compile_python!(get_output(progs[end]),mm)

    args_list = join(["v"*string(i) for i in get_args(mm)], ",")
    tables = ""
    for (t,i) in mm.tables
        tables *= "t"*string(i)*"=["
        tables *= join(["0x"hex(a) for a in t], ",")
        tables *= "]\n"
    end
    res = "def $name($args_list):$code"
    res *= "\n\treturn "returned_value
    tables*"\n"*res, mm
end


function compile_python!(p::Program, mm::MemoryManager)
    code = ""
    for ins in p.ins
        new_line = compile_python!(ins, mm)
        if new_line != ""
            code *=  "\n\t$new_line"
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

function compile_python!(x::NewArg, mm::MemoryManager)
    var = new_arg!(mm, x.len)
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
############################# Java Compilation #################################

compile_java(p::Program) = compile_java([p])

function compile_java(progs::Vector{Program}, name::String)
    mm = MemoryManager()
    code = compile_java!(progs[1], mm)    
    for i in 2:size(progs,1)
        flush_args(mm)
        code *= compile_java!(progs[i], mm, get_output(progs[i-1]))
    end
    returned_value = compile_java!(get_output(progs[end]),mm)

    args_list = join(["BigInteger v"*string(i) for i in get_args(mm)], ",")
    tables = ""
    for (t,i) in mm.tables
        tables *= "private static BigInteger[] t"*string(i)*"={"
        tables *= join(["new BigInteger(\""hex(a)*"\",16)" for a in t], ",")
        tables *= "};\n"
    end
    indices_set= Set()
    for i in get_variables(mm)
        if !(i in get_args(mm))
            push!(indices_set, i)
        end
    end
    variable_list = "BigInteger "join(["v"*string(i) for i in indices_set],",") *";\n"
    res = "import java.math.BigInteger;\n\n"
    res *= "public class $name{\n"
    res *= tables
    res *=      "public static BigInteger calc("*args_list*"){\n"
    res *= variable_list
    res *= code
    res *= "return "returned_value
    res *= "\n;}"#end of method calc
    res *= "\n}"#end of class
     
    res, mm
end


function compile_java!(p::Program, mm::MemoryManager)
    code = ""
    for ins in p.ins
        new_line = compile_java!(ins, mm)
        if new_line != ""
            code *=  new_line
        end
    end
    code
end

function compile_java!(p::Program, mm::MemoryManager, exp_in::Expression)
    code = compile_java!(p, mm)
    init = compile_java!(get_entry(p), mm)*
                      "="*compile_java!(exp_in, mm)*";\n"
    init*code
end

function compile_java!(x::Variable, mm::MemoryManager)
    x.ptr._affected != Nothing() || error("variable not initialized")
    "v"string(x.ptr._affected)
end

function compile_java!(x::NewVariable, mm::MemoryManager)
    var = new_variable!(mm, x.len)
    x._affected = var
    return ""
end

function compile_java!(x::NewArg, mm::MemoryManager)
    var = new_arg!(mm, x.len)
    x._affected = var
    return ""
end

compile_java!(x::Const, mm::MemoryManager) = "new BigInteger(\""hex(x.ptr)*"\",16)"

compile_java!(x::Affectation, mm::MemoryManager) =
    "v"string(x.dest.ptr._affected)"="compile_java!(x.src, mm)*";\n"

compile_java!(x::AccessTable, mm::MemoryManager) =
    "t"string(get_table_index!(mm, x.table))"["compile_java!(x.index, mm)".intValue()]"

for (T, Op) in ( (AND, "and"), (XOR, "xor"), (OR, "or"), (Add, "add"), 
               (Mul, "multiply"), (Mod, "mod") )
    @ eval compile_java!(x::($T), mm::MemoryManager) =
        compile_java!(x.left, mm) * "."*($Op)*"(" * compile_java!(x.right, mm)")"
end

for (T, Op) in ( (LShift, "shiftLeft"), (RShift, "shiftRight") )
    @eval compile_java!(x::($T), mm::MemoryManager) =
        compile_java!(x.left, mm) * "."*($Op)*"(" * compile_java!(x.right, mm)".intValue())"
end

############################## Utils functions ################################# 
import Base.hex
    
function hex(x::BitVector)
    res = hex(x.chunks[end])
    for i in size(x.chunks,1)-1:-1:1
        h = hex(x.chunks[i])
        res*= "0"^(16-length(h)) * h
    end
    res
end

end#module
