f = open("bram.txt", "w")

def move_imm_to_reg(f, t):
    v = (0 << 70)
    v |= t
    v |= (1 << (4+32)) | (f << 4)
    return v

def move_reg_to_reg(f, t):
    v = (0 << 70)
    v |= t
    v |= (0 << (4+32)) | (f << 4)
    return v

def add_reg_to_reg(f1, f2, t):
    v = (3 << 70)
    v |= t
    v |= f2 << 4
    v |= f1 << (4+32+1)
    return v

noop = move_reg_to_reg(15, 15)
mem = [noop for _ in range(256)]


mem[0] = move_imm_to_reg(1, 1)   # mov r1, 1
mem[1] = move_imm_to_reg(1, 2)   # mov r2, 1
mem[2] = noop                    # delay slot for r2 dep
# loop:
mem[3] = add_reg_to_reg(1, 2, 3) # add r3, r1 + r2
mem[4] = move_reg_to_reg(2, 1)   # mov r1, r2
mem[5] = move_reg_to_reg(3, 2)   # mov r2, r2
mem[6] = move_imm_to_reg(3, 0)   # jmp loop
mem[7] = noop                    # delay slot for jump

## Load
#mem[1] = (1 << 72)
## Store
#mem[2] = (2 << 72)
## Add
#mem[3] = (3 << 72)

for v in mem:
    f.write(f"{v:018x}\n")
