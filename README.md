# avt-vigenere-asm
Vigenere cypher implementation in x86 Assembly on 16 bits.

## How to Use
- Modify ASSEMBLE.BAT to set your assembler and linker directory path (e.g., E:\TASM).
- Run `ASSEMBLE.BAT` to build the application in MS-DOS.
- The output executable will be `VIGENERE.EXE`.
- Execute the program by providing comand-line arguments as follows:
  ```
  VIGENERE.EXE [key_file] [input_file] [output_file] [operation]
  ```
  where `[operation]` is either `e` for encrypt or `d` for decrypt.
- Example:
  `VIGENERE.EXE key.txt input.txt output.txt e`
- Ensure that the input file and the key are formated with uppercase letters only (A-Z), no spaces or punctuation.