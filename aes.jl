
module aes
using bboxlib
importall SBoxes
Key = Input(128, "Clef")
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

trans = PermBytes([1,5,9,13,  2,6,10,14,  3,7,11,15,  4,8,12,16])
MixColumns = trans >> Map(mc, 128) >> trans

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

InvMixColumns = trans >> Map(imc, 128) >> trans
InvAES = Message >> AddRoundKey >> InvMixColumns >> InvShiftRows >> InvSubBytes


# Tests...
n = 10000
c = 0
for i in 1:n
    message = randbool((128,))
    key = randbool((128,))
    cypher=bboxlib._eval(aes.AES, {"Message"=> message, "Clef"=> key}, BitVector(0))
    if bboxlib._eval(aes.InvAES, {"Message"=> cypher, "Clef"=> key}, BitVector(0)) == message
        c +=1
    end
end
println("$c/$n tests passés !")
    

end
