
module aes
using bboxlib
importall SBoxes

Key = Input(128, "Key")
Message = Input(128, "Message")

Rij = SBox(SBoxes.Rijndeal)
SubBytes = Map(Rij, 128)
permrows = [1, 2, 3, 4,   6, 7, 8, 5,   11, 12, 9, 10,   16, 13, 14, 15]
ShiftRows = PermBytes(permrows)
AddRoundKey = UXOR(Key)

# MixColumns
two = SBox(SBoxes.GF8_TIMES_2)
three = SBox(SBoxes.GF8_TIMES_3)
id = Neutral()
mc = BFMatrix( [two three id id; 
                id two three id ; 
                id id two three ; 
                three id id two], BXOR)

MixColumns = Map(mc, 128)

AES = Message >> SubBytes >> ShiftRows >> MixColumns >> AddRoundKey
################################## Inverse AES ############################

InvSubBytes = Map(SBox(SBoxes.RijndealInv), 128)
InvShiftRows = PermBytes(invperm(permrows))
bai = SBox(SBoxes.GF8_TIMES_B)
neuf = SBox(SBoxes.GF8_TIMES_9)
dai = SBox(SBoxes.GF8_TIMES_D)
euh = SBox(SBoxes.GF8_TIMES_E)

imc = BFMatrix(BoolFunc[euh bai dai neuf;
                neuf euh bai dai;
                dai neuf euh bai;
                bai dai neuf euh], BXOR)

InvMixColumns = Map(imc, 128) 
InvAES = Message >> AddRoundKey >> InvMixColumns >> InvShiftRows >> InvSubBytes

# Tests...
#n = 100
#c = 0
#for i in 1:n
#    message = randbool((128,))
#    key = randbool((128,))
#    cypher=bboxlib._eval(aes.AES, {"Message"=> message, "Key"=> key}, BitVector(0))
#    if bboxlib._eval(aes.InvAES, {"Message"=> cypher, "Key"=> key}, BitVector(0)) == message
#        c +=1
#    end
#end
#println("$c/$n tests passés !")
using bboxcompile;
using simplelanguage; 
println("BBox AES parsed.")
println("Compile BBox to SL...")
algo = aes.AES
p = compile_sl(algo)
println("Done.")
println("Compile SL to python...")
code, mm = compile_python([p, compile_sl(aes.InvAES)], "aes")
f= open("testaes.py","w")
write(f, code)
close(f)
println("Done, result written in testaes.py.")
println("Compile SL to java...")
code, mm = compile_java([p, compile_sl(aes.InvAES)], "Testaes")
f= open("Testaes.java","w")
write(f, code)
close(f)
println("Done, result written in Testaes.java.")


end
