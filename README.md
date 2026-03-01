# Lua-Hexdump

![Lua](https://img.shields.io/badge/Lua-5.1%2B-blue?logo=lua&style=for-the-badge)
![LuaJIT](https://img.shields.io/badge/LuaJIT-compatible-orange?style=for-the-badge)
![License](https://img.shields.io/badge/license-MIT-green?style=for-the-badge)

Visualizador hexadecimal escrito em Lua. Exibe qualquer arquivo no formato clássico de hexdump com coluna ASCII, otimizado para baixo uso de memória e mínima pressão sobre o garbage collector. Pode ser usado diretamente pelo terminal ou importado como módulo em outros scripts Lua.

---

## Idiomas

- [Português](#português)
- [English](#english)

---

## Português

### Requisitos

- Lua 5.1+ ou LuaJIT
- Windows, Linux ou macOS

### Instalação

Sem dependências externas. Simplismente baixe o arquivo `hexdump.lua` e um interpretador Lua disponível no sistema.

### Uso

#### Terminal

```
lua hexdump.lua <arquivo>
luajit hexdump.lua <arquivo>
```

Para salvar o dump em um arquivo:

```
lua hexdump.lua imagem.png > dump.txt
```

> O dump hexadecimal é escrito no `stdout` e o resumo no `stderr`.  
> O operador `>` redireciona apenas o dump, mantendo o resumo visível no terminal.

#### Como módulo

```lua
local hexdump = require("hexdump")

-- Uso simples
hexdump.dump("imagem.png")

-- Uso avançado: formato de saída personalizado
hexdump.dump("imagem.png", {
    on_format_line = function(byte_offset, raw_bytes)
        local hex_values = {}
        for col = 1, #raw_bytes do
            hex_values[#hex_values + 1] = string.format("%02X", raw_bytes:byte(col))
        end
        return string.format("[%08X] %s", byte_offset, table.concat(hex_values, " "))
    end
})
```

### Saída

```
00000000  89 50 4E 47 0D 0A 1A 0A  00 00 00 0D 49 48 44 52  |.PNG........IHDR|
00000010  00 00 00 10 00 00 00 10  08 02 00 00 00 90 91 73  |...............s|
...
Arquivo    : imagem.png
Tamanho    : 1.2 KB (1245 bytes)
Tempo    : 0.002 s
```

Cada linha exibe:

- **Offset** — posição do primeiro byte da linha no arquivo, em hexadecimal
- **Coluna hex** — valor de cada byte em hexadecimal, separados por espaço
- **Coluna ASCII** — representação visual dos bytes imprimíveis; bytes fora do intervalo 0x20–0x7E são exibidos como `.`

O idioma do resumo segue o locale do sistema. Em sistemas com `LANG`, `LANGUAGE` ou `LC_ALL` contendo `pt`, o resumo é exibido em português. Em qualquer outro locale, o padrão é inglês.

### Casos de uso

- Inspecionar arquivos binários, imagens e executáveis
- Verificar cabeçalhos e assinaturas de formato de arquivo
- Depurar dados transmitidos em protocolos binários
- Integrar em ferramentas Lua existentes via `require`

### Extensibilidade

O pipeline interno é composto por quatro hooks nomeados. Ao usar o módulo, qualquer hook pode ser substituído passando uma tabela de substituições como segundo argumento de `hexdump.dump()`:

| Hook | Comportamento padrão | Assinatura |
|---|---|---|
| `on_open_file` | Abre o arquivo em modo binário | `(filepath) → handle, err` |
| `on_format_line` | Formato clássico de hexdump | `(byte_offset, raw_bytes) → string` |
| `on_write_output` | Escreve o buffer no stdout | `(lines_table) → lines_table` |
| `on_show_summary` | Exibe o resumo no stderr | `(filepath, total_bytes, elapsed_seconds)` |

O formato clássico também está disponível como referência direta:

```lua
local hexdump = require("hexdump")

hexdump.dump("arquivo.bin", {
    on_format_line = hexdump.formats.classic
})
```

### Decisões de implementação

| Aspecto | Decisão | Motivo |
|---|---|---|
| Leitura em chunks de 4 KB | `READ_BUFFER_SIZE = 4096` | Evita carregar o arquivo inteiro na memória |
| Flush a cada 1000 linhas | `FLUSH_INTERVAL = 1000` | Libera memória periodicamente sem overhead de I/O excessivo |
| Tabela de lookup hex pré-computada | `HEX_LOOKUP[0..255]` | Elimina chamadas a `string.format` por byte no hot path |
| Reutilização da tabela de buffer | Limpa com `nil` em vez de `{}` | Evita alocar nova tabela a cada flush |
| Concatenação via `table.concat` | Evita `..` em loops | Reduz alocações intermediárias e pressão sobre o GC |

---

## English

### Requirements

- Lua 5.1+ or LuaJIT
- Windows, Linux or macOS

### Installation

No external dependencies. Simply download the `hexdump.lua` file and a Lua interpreter available on your system.

### Usage

#### Command line

```
lua hexdump.lua <file>
luajit hexdump.lua <file>
```

To save the dump to a file:

```
lua hexdump.lua image.png > dump.txt
```

> The hex dump is written to `stdout` and the summary to `stderr`.  
> The `>` operator redirects only the dump, keeping the summary visible in the terminal.

#### As a module

```lua
local hexdump = require("hexdump")

-- Simple usage
hexdump.dump("image.png")

-- Advanced usage: custom output format
hexdump.dump("image.png", {
    on_format_line = function(byte_offset, raw_bytes)
        local hex_values = {}
        for col = 1, #raw_bytes do
            hex_values[#hex_values + 1] = string.format("%02X", raw_bytes:byte(col))
        end
        return string.format("[%08X] %s", byte_offset, table.concat(hex_values, " "))
    end
})
```

### Output

```
00000000  89 50 4E 47 0D 0A 1A 0A  00 00 00 0D 49 48 44 52  |.PNG........IHDR|
00000010  00 00 00 10 00 00 00 10  08 02 00 00 00 90 91 73  |...............s|
...
File    : image.png
Size    : 1.2 KB (1245 bytes)
Time    : 0.002 s
```

Each line displays:

- **Offset** — position of the first byte in the line within the file, in hexadecimal
- **Hex column** — value of each byte in hexadecimal, space-separated
- **ASCII column** — visual representation of printable bytes; bytes outside the 0x20–0x7E range are shown as `.`

The summary language follows the system locale. On systems where `LANG`, `LANGUAGE` or `LC_ALL` contains `pt`, the summary is displayed in Portuguese. For any other locale, English is the default.

### Use cases

- Inspect binary files, images, and executables
- Verify file format headers and signatures
- Debug data transmitted over binary protocols
- Integrate into existing Lua tools via `require`

### Extensibility

The internal pipeline is composed of four named hooks. When using the module, any hook can be replaced by passing an overrides table as the second argument to `hexdump.dump()`:

| Hook | Default behavior | Signature |
|---|---|---|
| `on_open_file` | Opens file in binary mode | `(filepath) → handle, err` |
| `on_format_line` | Classic hexdump format | `(byte_offset, raw_bytes) → string` |
| `on_write_output` | Writes buffer to stdout | `(lines_table) → lines_table` |
| `on_show_summary` | Prints summary to stderr | `(filepath, total_bytes, elapsed_seconds)` |

The classic format function is also exposed as a direct reference:

```lua
local hexdump = require("hexdump")

hexdump.dump("file.bin", {
    on_format_line = hexdump.formats.classic
})
```

### Implementation decisions

| Aspect | Decision | Reason |
|---|---|---|
| Reading in 4 KB chunks | `READ_BUFFER_SIZE = 4096` | Avoids loading the entire file into memory |
| Flush every 1000 lines | `FLUSH_INTERVAL = 1000` | Periodically releases memory without excessive I/O overhead |
| Pre-computed hex lookup table | `HEX_LOOKUP[0..255]` | Eliminates `string.format` calls per byte in the hot path |
| Buffer table reuse | Clear with `nil` instead of `{}` | Avoids allocating a new table on every flush |
| Concatenation via `table.concat` | Avoids `..` in loops | Reduces intermediate allocations and GC pressure |

---

## Licença / License

MIT © [NexaRift](https://github.com/NexaRift)
