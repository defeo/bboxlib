
module aes
using bboxlib
importall SBoxes
Key = Input(128, "Clef")
Message = Input(128, "Message")

Rij = SBox(SBoxes.Rijndeal)
SubBytes = Map(Rij, 16)
ShiftRows = PermBytes([1, 2, 3, 4,   6, 7, 8, 5,   11, 12, 9, 10,   16, 13, 14, 15])
AddRoundKey = UXOR(Key)

# MixColumns
#  [[2,3,1,1], [1,2,3,1], [1,1,2,3], [3,1,1,2]]
two = SBox(SBoxes.GF8_TIMES_2)
three = SBox(SBoxes.GF8_TIMES_3)
mc = (
        ( Slice(1,8) >> two 
        + Slice(9,16) >> three
        + Slice(17,24) 
        + Slice(25,32)  )  
            >> BXOR(8) 
    ) + (
        ( Slice(1,8) 
        + Slice(9,16) >> two
        + Slice(17,24) >> three 
        + Slice(25,32)  )  
            >> BXOR(8) 
    ) + (
        ( Slice(1,8) 
        + Slice(9,16)
        + Slice(17,24) >> two 
        + Slice(25,32) >> three )  
            >> BXOR(8)
    ) + (
        ( 
          Slice(1,8) >> three 
        + Slice(9,16) 
        + Slice(17,24) 
        + Slice(25,32) >> two )  
            >> BXOR(8)
    )

trans = PermBytes([1,5,9,13,  2,6,10,14,  3,7,11,15,  4,8,12,16])

MixColumns = trans >> (
    (mc << Slice(1,32))
    + (mc << Slice(33,64))
    + (mc << Slice(65,96))
    + (mc << Slice(97,128))) >> trans

AES = Message >> SubBytes >> ShiftRows >> MixColumns >> AddRoundKey

end
