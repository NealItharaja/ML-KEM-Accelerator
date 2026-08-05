#!/usr/bin/env python3
from pathlib import Path

paths = [
    Path(r"C:/Users/neali/librelane/ML-KEM-Accelerator/src/kem.v"),
    Path(r"C:/Users/neali/librelane/ML-KEM-Accelerator/tools/gen_kem_v.py"),
]

for p in paths:
    t = p.read_text(encoding="utf-8")
    if "reg         ops_kick;" not in t and "reg ops_kick;" not in t:
        t = t.replace(
            "reg         ops_start;",
            "reg         ops_start;\n    reg         ops_kick;",
            1,
        )

    # reset init
    t = t.replace(
        "ops_start <= 1'b0;\n            sn_start <= 1'b0;",
        "ops_start <= 1'b0;\n            ops_kick <= 1'b0;\n            sn_start <= 1'b0;",
        1,
    )

    old = """            ops_start <= 1'b0;
            sn_start <= 1'b0;
            c2s <= 1'b0;
            c3s <= 1'b0;"""
    new = """            ops_start <= 1'b0;
            if (ops_kick)
                ops_start <= 1'b1;
            ops_kick <= 1'b0;
            sn_start <= 1'b0;
            c2s <= 1'b0;
            c3s <= 1'b0;"""
    if old in t:
        t = t.replace(old, new, 1)
    else:
        print(p.name, "WARN: runtime block not found")

    t = t.replace("ops_start <= 1'b1;", "ops_kick <= 1'b1;")
    p.write_text(t, encoding="utf-8")
    print(p.name, "ops_kick count", t.count("ops_kick"), "bare ops_start=1", t.count("ops_start <= 1'b1;"))
