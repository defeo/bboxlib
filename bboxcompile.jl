module bboxcompile

export compile_sl

using simplelanguage 
using bboxlib
import bboxlib.Seq
import bboxlib.Cat

slCst = simplelanguage.Const

compile_sl!(x::Const, p::Program, v::Expression) = slCst(x.val)

function compile_sl!(x::Slice, p::Program, v::Expression)
    mask =  BitVector(x.term)
    mask[x.start:x.term] = true
    if x.start == 1
        AND(v, slCst(mask))
    else
        RShift(AND(v, slCst(mask)), slCst(x.start-1))
    end
end

function compile_sl!(x::Seq, p::Program, v::Expression)
    for f in x.funcs
        v = compile_sl!(f, p, v)
    end
    v
end

function compile_sl!(x::BXOR, p::Program, v::Expression)
    in_size, out_size = size(x)
    ins = NewVariable(in_size)
    add_instruction!(p, ins)
    in_var = Variable(ins)
    add_instruction!(p, Affectation(in_var, v))
    compile_sl!(x, p, in_var)
end

function compile_sl!(x::BXOR, p::Program, in_var::Variable)
    in_size, out_size = size(x)
    mask = BitVector(in_size)
    mask[1:out_size]=true
    res = AND(in_var, slCst(mask))
    for i in out_size:out_size:in_size-1
        mask >>= out_size
        res = XOR(res, RShift(AND(in_var, slCst(mask)), slCst(i)))
    end
    res
end

for (T1, T2) in ((BAddMod, Add), (BMulMod, Mul))
    @eval function compile_sl!(x::($T1), p::Program, v::Expression)
        in_size, out_size = size(x)
        nv_ins = NewVariable(in_size)
        add_instruction!(p, nv_ins)
        nv = Variable(nv_ins)
        add_instruction!(p, Affectation(nv, v))
        mask = BitVector(in_size)
        mask[1:out_size]=true
        res = AND(nv, slCst(mask))
        mod = BitVector(out_size+1)
        mod[end] = true
        for i in out_size:out_size:in_size-1
            mask >>= out_size
            res = Mod(Add(res, RShift(AND(nv, slCst(mask)), slCst(i))), slCst(mod))
        end
    end
end

function compile_sl!(x::Cat, p::Program, v::Expression)
    in_size, out_size = size(x)
    in_var_ins = NewVariable(in_size)
    add_instruction!(p, in_var_ins)
    in_var = Variable(in_var_ins)
    add_instruction!(p, Affectation(in_var, v))
    compile_sl!(x, p, in_var)
end

function compile_sl!(x::Cat, p::Program, in_var::Variable)    
    out_exp = compile_sl!(x.funcs[1], p, in_var)
    shift = sizeOut(x.funcs[1])
    for f in x.funcs[2:end]
        out_exp = OR(out_exp, LShift(compile_sl!(f, p, in_var), slCst(shift)))
        shift += sizeOut(f)
    end
    out_exp
end

compile_sl!(x::UXOR, p::Program, v::Expression) =
    XOR(v, compile_sl!(x.func, p, NilExp()))
    
function compile_sl!(x::Input, p::Program, v::NilExp)
    nv_ins = NewArg(sizeOut(x))
    add_instruction!(p, nv_ins)
    var = Variable(nv_ins)

    if x.name == "Message"
        set_entry!(p, var)
    end
    var
end

compile_sl!(x::SBox, p::Program, v::Expression) = AccessTable(x.table, v)

function compile_sl(x::BoolFunc)
    p = Program()
    # the entry point of the program will be add during the compilation
    # when an Input of name "Message" will be encounter.
    exp_out = compile_sl!(x, p, NilExp())
    set_output!(p, exp_out)
    p
end
   
end#end module
