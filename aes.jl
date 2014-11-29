
module aes
using bboxlib

Key = Input(128)
Message = Input(128)

Rij = SBox([BitVector(8) for i in 1:256])
SubBytes = sum( [Slice(8(i-1)+1, 8i) >> Rij for i in 1:16])
ShiftRows = PermBytes([1, 2, 3, 4,   6, 7, 8, 5,   11, 12, 9, 10,   16, 13, 14, 15])
AddRoundKey = XOR(Key)

# MixColumns
#  [[2,3,1,1], [1,2,3,1], [1,1,2,3], [3,1,1,2]]
one = SBox([BitVector(8) for i in 1:256])
two = SBox([BitVector(8) for i in 1:256])
three = SBox([BitVector(8) for i in 1:256])
mc = (
    (Slice(1,8) >> two >> XOR(
        Slice(9,16) >> three >> XOR(
            Slice(17,24) >> one >> XOR(
                Slice(25,32) >> one))))
    + (Slice(1,8) >> one >> XOR(
        Slice(9,16) >> two >> XOR(
            Slice(17,24) >> three >> XOR(
                Slice(25,32) >> one))))
    + (Slice(1,8) >> one >> XOR(
        Slice(9,16) >> one >> XOR(
            Slice(17,24) >> two >> XOR(
                Slice(25,32) >> three))))
    + (Slice(1,8) >> three >> XOR(
        Slice(9,16) >> one >> XOR(
            Slice(17,24) >> one >> XOR(
                Slice(25,32) >> two)))))

trans = (
    Slice(1,8) + Slice(33,40) + Slice(65,72) + Slice(97,104)
    + Slice(9,16) + Slice(41,48) + Slice(73,80) + Slice(105,112)
    + Slice(17,24) + Slice(49,56) + Slice(81,88) + Slice(113,120)
    + Slice(25,32) + Slice(57,64) + Slice(89,96) + Slice(121,128)
)

MixColumns = trans >> (
    (mc << Slice(1,32))
    + (mc << Slice(33,64))
    + (mc << Slice(65,96))
    + (mc << Slice(97,128))) >> trans

AES = Message >> SubBytes >> ShiftRows >> MixColumns >> AddRoundKey


end
