
module aes
using bboxlib
importall SBoxes
Key = Input(128, "Clef")
Message = Input(128, "Message")

Rij = SBox(SBoxes.Rijndeal)
SubBytes = Map(Rij, 128)
ShiftRows = PermBytes([1, 2, 3, 4,   6, 7, 8, 5,   11, 12, 9, 10,   16, 13, 14, 15])
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
end
