"""
Usage: python gcc2ripes.py gcc.s tables.s gfull.s [tool-prefix]

Steps:
 1. drop directives Ripes does not know (.file .option .attribute ...),
    map .section/.bss to .text/.data, '.set X,.+0' -> 'X:',
    rename '.Lxx' labels to 'L_xx'
 1b. GNU ".align N" means 2^N bytes, Ripes ".align N" means N bytes
     (gnudirectives.cpp), so GCC's ".align 2" becomes ".align 4"
 2. add a 3-line _start (call main; exit ecall) in front
 3. append tables.s
 4. Ripes computes %hi/%lo without the +0x800 rounding (rvrelocations.h),
    so assemble+link once with GNU binutils (.data at 0x10000000, same as
    Ripes), read symbol addresses, and write %hi(..)/%lo(..) as numbers.
GCC's instructions are not changed; only the operand text is resolved.
"""
import re, subprocess, sys, os

src, tables, dst = sys.argv[1:4]
pre = sys.argv[4] if len(sys.argv) > 4 else "riscv-none-elf-"
exe = ".exe" if os.name == "nt" else ""

out = [".text", ".globl _start", "_start:", "    call main", "    li a7, 10", "    ecall"]
for line in open(src, encoding="utf-8"):
    s = line.strip()
    if re.match(r"\.(file|option|attribute|ident|type|size|globl)\b", s):
        continue
    if s.startswith("#"):
        continue
    if s.startswith(".section"):
        out.append(".text" if ".text" in s else ".data")
        continue
    if s == ".bss":
        out.append(".data")
        continue
    m = re.match(r"\.set\s+(\S+),\s*\.\s*\+\s*0$", s)
    if m:
        out.append(m.group(1) + ":")
        continue
    m = re.match(r"\.(p2)?align\s+(\d+)", s)
    if m:  # GNU: .align N = 2^N bytes; Ripes: .align N = N bytes
        out.append("    .align %d" % (1 << int(m.group(2))))
        continue
    out.append(line.rstrip())
text = "\n".join(out) + "\n"
text = re.sub(r"\.L(\w+)", r"L_\1", text)
text += ".text\nL_END_OF_TEXT:\n"
text += open(tables, encoding="utf-8").read()

tmp = dst + ".tmp.s"
# GNU copy: write Ripes-style ".align N bytes" as ".balign N" so both agree
open(tmp, "w", encoding="utf-8").write(re.sub(r"\.align\b", ".balign", text))
subprocess.run([pre + "as" + exe, "-march=rv32i", "-mabi=ilp32", tmp, "-o", tmp + ".o"], check=True)
subprocess.run([pre + "ld" + exe, "-m", "elf32lriscv", "--no-relax", "-Ttext=0",
                "-Tdata=0x10000000", "-e", "_start", tmp + ".o", "-o", tmp + ".elf"], check=True)
nm = subprocess.run([pre + "nm" + exe, tmp + ".elf"], capture_output=True, text=True, check=True).stdout
addr = {}
for l in nm.splitlines():
    p = l.split()
    if len(p) == 3:
        addr[p[2]] = int(p[0], 16)

def value(expr):
    m = re.fullmatch(r"(\w+)\s*([+-]\s*\d+)?", expr.strip())
    return addr[m.group(1)] + (int(m.group(2).replace(" ", "")) if m.group(2) else 0)

def hi(m):
    return str(((value(m.group(1)) + 0x800) >> 12) & 0xFFFFF)

def lo(m):
    v = value(m.group(1))
    return str(v - ((((v + 0x800) >> 12) & 0xFFFFF) << 12))

text = re.sub(r"%hi\(([^)]*)\)", hi, text)
text = re.sub(r"%lo\(([^)]*)\)", lo, text)
open(dst, "w", encoding="utf-8").write(text)
for f in (tmp, tmp + ".o", tmp + ".elf"):
    os.remove(f)
print("wrote", dst)
print("main code size: %d bytes (%d instructions), not counting _start"
      % (addr["L_END_OF_TEXT"] - addr["main"], (addr["L_END_OF_TEXT"] - addr["main"]) // 4))
