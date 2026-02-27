# hexdump.lua

![Lua](https://img.shields.io/badge/Lua-5.1%2B-blue?logo=lua) ![LuaJIT](https://img.shields.io/badge/LuaJIT-compatible-orange) ![License](https://img.shields.io/badge/license-MIT-green)

A simple and efficient hexadecimal viewer written in Lua.  
Displays any file in classic hexdump format with ASCII column.  
Ideal for inspecting binary files, images, executables, and more.

---

## 🌐 Languages / Idiomas
- [English](#english)
- [Português](#português)

---

## English

### Requirements

- Lua 5.1+ or LuaJIT
- Windows, Linux or macOS

### Features

- Efficient 4KB buffered reading
- Flushes every 1000 lines to avoid memory bloat
- Precomputed lookup table for fast byte-to-hex conversion
- Works with LuaJIT and Lua 5.1+
- Shows file size summary and processing time
- Output language follows system locale (English/Portuguese)

### Usage

```bash
lua hexdump.lua <file>
# or with LuaJIT
luajit hexdump.lua <file>
```

To save output to a text file:

```bash
lua hexdump.lua image.png > dump.txt
```

> **Note:** the hex dump is written to `stdout` and the summary to `stderr`.  
> This means `>` redirects only the dump, keeping the summary visible in the terminal.

### Example

```bash
$ lua hexdump.lua example.bin
00000000  89 50 4E 47 0D 0A 1A 0A  00 00 00 0D 49 48 44 52  |.PNG........IHDR|
00000010  00 00 00 10 00 00 00 10  08 02 00 00 00 90 0F  ...|
...
File    : example.bin
Size    : 1.2 KB (1245 bytes)
Time    : 0.002 s
```

### Installation

No dependencies. Just download `hexdump.lua` and run it with Lua 5.1+ or LuaJIT.

---

## Português

### Requisitos

- Lua 5.1+ ou LuaJIT
- Windows, Linux ou macOS

### Características

- Leitura eficiente com buffer de 4KB
- Liberação automática a cada 1000 linhas (evita acúmulo de memória)
- Tabela pré-computada para conversão rápida byte → hex
- Compatível com LuaJIT e Lua 5.1+
- Exibe resumo com tamanho do arquivo e tempo de processamento
- Idioma da saída segue o locale do sistema (inglês/português)

### Uso

```bash
lua hexdump.lua <arquivo>
# ou com LuaJIT
luajit hexdump.lua <arquivo>
```

Para salvar a saída em um arquivo de texto:

```bash
lua hexdump.lua imagem.png > dump.txt
```

> **Nota:** o dump hexadecimal é escrito no `stdout` e o sumário no `stderr`.  
> Isso significa que `>` redireciona apenas o dump, mantendo o sumário visível no terminal.

### Exemplo

```bash
$ lua hexdump.lua exemplo.bin
00000000  89 50 4E 47 0D 0A 1A 0A  00 00 00 0D 49 48 44 52  |.PNG........IHDR|
00000010  00 00 00 10 00 00 00 10  08 02 00 00 00 90 0F  ...|
...
Arquivo : exemplo.bin
Tamanho : 1.2 KB (1245 bytes)
Tempo   : 0.002 s
```

### Instalação

Sem dependências. Basta baixar o arquivo `hexdump.lua` e executar com Lua 5.1+ ou LuaJIT.

---

## License / Licença

MIT © [NexaRift](https://github.com/NexaRift)
