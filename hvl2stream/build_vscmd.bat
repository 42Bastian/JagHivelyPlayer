cl /c /nologo /O2 main.c
cl /c /nologo /O2 hvl_replay.c
cl /c /nologo /O2 hvl_tables.c
cl /nologo /Fe:hvl2stream.exe *.obj
