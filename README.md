# Lua-Hexdump

![Lua](https://img.shields.io/badge/Lua-5.1%2B-blue?logo=lua&style=for-the-badge)
![LuaJIT](https://img.shields.io/badge/LuaJIT-compatible-orange?style=for-the-badge)
![License](https://img.shields.io/badge/license-MIT-green?style=for-the-badge)

`hexdump.lua` is a binary inspection tool written in pure Lua that brings the classic `hexdump -C` experience to any environment where Lua or LuaJIT runs — from embedded systems to CI pipelines. It reads files in streaming chunks to keep memory usage flat regardless of file size, formats each byte group into the familiar offset + hex + ASCII layout, and exposes a clean hook system so every stage of the pipeline — file opening, line formatting, output writing, and the final summary — can be replaced or extended without touching the core code. Whether you need to pipe the dump to a file, reformat it as JSON, read from an in-memory string instead of disk, or just drop it in as a module inside a larger Lua project, the same four hooks cover all of it. Zero external dependencies, compatible with Lua 5.1 and above (including LuaJIT), and ready to use straight from the command line.

---

## Table of Contents

- [Overview](#overview)
- [Processing Pipeline](#processing-pipeline)
- [Installation](#installation)
- [Basic Usage (CLI)](#basic-usage-cli)
- [Module Usage](#module-usage)
- [Customization Hooks](#customization-hooks)
- [Output Format](#output-format)
- [Implementation Decisions & Optimizations](#implementation-decisions--optimizations)
- [Known Limitations](#known-limitations)
- [License](#license)

---

## Overview

`hexdump.lua` is a hexadecimal visualizer that reads any binary file and displays its content in the classic format:

- Hexadecimal offset (8 digits)
- 16 bytes per line in hex (two 8-byte blocks separated by two spaces)
- ASCII column with printable characters (0x20–0x7E); bytes outside this range appear as `.`

**Key features:**
- Reads in 4 KB chunks → low memory footprint
- Accumulates lines and flushes every 1000 → reduces I/O calls
- Lookup table for byte → hex conversion → eliminates `string.format` in the hot path
- Table reuse → avoids allocations and GC pressure
- Fully customizable via hooks (open, format, write, summary)
- Detects system locale (Portuguese or English) for summary messages

---

## Processing Pipeline

The internal pipeline follows these steps:

```
File → read in 4KB chunks → split into 16-byte groups →
format each group as a line → accumulate in buffer →
flush every 1000 lines (or EOF) → write to stdout →
display summary to stderr
```

### Pipeline Stages

| Stage | Description | Corresponding Hook |
|-------|-------------|-------------------|
| Open | Opens the file in binary mode (`"rb"`) | `on_open_file` |
| Block read | Reads `READ_BUFFER_SIZE` (4096) bytes at a time | internal |
| Line split | Breaks the block into `BYTES_PER_LINE` (16)-byte chunks | internal |
| Formatting | Converts offset and raw bytes into a text line | `on_format_line` |
| Buffering | Accumulates lines in a table | internal |
| Flush | When `#line_buffer >= FLUSH_INTERVAL` (1000), writes out | `on_write_output` |
| Summary | At the end, displays filename, size, and elapsed time | `on_show_summary` |
| Close | Closes the file handle | internal |

---

## Installation

No dependencies. Just grab `hexdump.lua`:

```bash
curl -O https://raw.githubusercontent.com/NexaRift/Lua-Hexdump/main/hexdump.lua
```

(Optional) Make it executable on Unix:

```bash
chmod +x hexdump.lua
```

---

## Basic Usage (CLI)

```bash
lua hexdump.lua <file>
luajit hexdump.lua <file>
```

Redirect the dump to a file (the summary still appears in the terminal):

```bash
lua hexdump.lua image.png > dump.txt
```

Sample output:

```
00000000  89 50 4E 47 0D 0A 1A 0A  00 00 00 0D 49 48 44 52  |.PNG........IHDR|
00000010  00 00 00 10 00 00 00 10  08 02 00 00 00 90 91 73  |...............s|
...
File   : image.png
Size   : 1.2 KB (1245 bytes)
Time   : 0.002 s
```

---

## Module Usage

```lua
local hexdump = require("hexdump")

-- Simple dump
hexdump.dump("file.bin")

-- With customization (example: compact format)
hexdump.dump("file.bin", {
    on_format_line = function(offset, bytes)
        local hex = {}
        for i = 1, #bytes do
            hex[i] = string.format("%02X", bytes:byte(i))
        end
        return string.format("%08X: %s", offset, table.concat(hex, " "))
    end
})
```

---

## Customization Hooks

The four hooks let you modify any part of the pipeline. They are passed as a dictionary in the second argument of `hexdump.dump()`.

| Hook | Signature | Default Behavior | Typical Use |
|------|-----------|-----------------|-------------|
| `on_open_file` | `(self, filepath) → handle, err` | `io.open(filepath, "rb")` | Open from a string, network, or encrypted file |
| `on_format_line` | `(byte_offset, raw_bytes) → string` | `hexdump.formats.classic` | Alternative formats (JSON, CSV, hex-only) |
| `on_write_output` | `(self, lines_table) → lines_table` | `io.write(table.concat(lines, "\n") .. "\n")` and returns a cleared table | Write to a file, compress, send over the network |
| `on_show_summary` | `(self, filepath, total_bytes, elapsed_seconds)` | Prints to stderr (locale-aware) | Suppress, format as JSON, log |

> **Note on signatures:** `on_open_file`, `on_write_output`, and `on_show_summary` are called as Lua methods (colon syntax), so the dumper instance is always passed as the first argument `self`. Use `_` to discard it if not needed. `on_format_line` is the exception — it is called as a plain function (dot syntax) and receives no `self`.

### Example: save dump to a file (instead of stdout)

```lua
local out = io.open("dump.txt", "w")
hexdump.dump("image.png", {
    on_write_output = function(_, lines)  -- _ discards the implicit self
        out:write(table.concat(lines, "\n"), "\n")
        out:flush()
        for i = 1, #lines do lines[i] = nil end
        return lines
    end
})
out:close()
```

### Example: summary as JSON on stdout

```lua
hexdump.dump("file.bin", {
    on_show_summary = function(_, path, size, elapsed)  -- _ discards the implicit self
        local summary = string.format(
            '{"file":"%s","bytes":%d,"time_sec":%.3f}',
            path, size, elapsed
        )
        io.write(summary, "\n")
    end
})
```

### Example: open from a string (useful for tests)

```lua
-- Use a factory so the data is captured via closure.
-- The hook receives (self, filepath) but both can be discarded here.
local function make_string_source(content)
    return function(_, _)
        local handle = {
            data = content,
            pos  = 1,
            seek = function(self, whence, offset)
                if whence == "end" then return #self.data end
                if whence == "set" then self.pos = (offset or 0) + 1 end
                return self.pos - 1
            end,
            read = function(self, n)
                local chunk = self.data:sub(self.pos, self.pos + n - 1)
                self.pos = self.pos + #chunk
                return chunk
            end,
            close = function() end
        }
        return handle, nil
    end
end

hexdump.dump("dummy", { on_open_file = make_string_source("\x89PNG\r\n\x1a\x0a...") })
```

---

## Output Format

The default formatting function `hexdump.formats.classic` produces lines with this structure:

```
<offset>  <hex bytes (16)>  |<ascii>|
```

- **Offset**: 8 hexadecimal digits, zero-padded (e.g. `00000000`)
- **Hex bytes**: two hex characters per byte; after the 8th byte, two extra spaces (`"  "`) separate the two 8-byte groups
- **ASCII**: printable characters (0x20–0x7E) shown literally; all other bytes (including newline, tab, bytes > 126) appear as `.`

---

## Implementation Decisions & Optimizations

| Aspect | Choice | Rationale |
|--------|--------|-----------|
| Reading | `FILE:read(4096)` | Avoids loading the entire file into memory; 4 KB is a good balance between syscalls and overhead |
| Grouping | 16 bytes per line (`BYTES_PER_LINE`) | Standard terminal width (16 × 3 ≈ 48 cols + offset and ASCII) |
| Line buffer | `FLUSH_INTERVAL = 1000` | Batch writes reduce `io.write` calls; 1000 lines ≈ 60 KB, very tolerable |
| Byte → hex conversion | Pre-computed lookup table (`HEX_LOOKUP[0..255]`) | Eliminates `string.format("%02X", byte)` in the inner loop; micro-optimization relevant for large files |
| Buffer table reuse | Set slots to `nil` instead of allocating `{}` | Avoids a new table allocation per flush, reducing GC pressure |
| Concatenation | `table.concat` instead of `..` in loops | Avoids intermediate string allocations (each `..` creates a new string); `table.concat` does it in a single allocation |
| Locale detection | Checks `LANG`, `LANGUAGE`, `LC_ALL` for "pt" | Works on any platform where these variables are set; falls back to English when none of them is defined or contains `"pt"` (common on Windows by default, but can be overridden by setting `LANG=pt_BR`) |
| stdout vs stderr | Dump → stdout, summary → stderr | Allows redirecting the dump (`> file`) without losing the human-readable summary |

---

## Known Limitations

- The ASCII column only shows **basic printable ASCII (0x20–0x7E)**. Accented characters, multibyte UTF-8, and most control codes are rendered as `.`.
- The program does not interpret file encoding — it treats each byte individually.
- Not all traditional `hexdump` options are supported (e.g. `-C`, `-b`, `-x`, `-s`, `-n`). These can be implemented via hooks but are not included by default.
- On systems where `os.clock()` measures CPU time (rather than wall time), the reported value may differ slightly from elapsed real time. For most Lua implementations (PUC-Rio and LuaJIT on POSIX), `os.clock()` returns CPU time, which is useful for evaluating algorithmic performance.
- For files larger than 2 GB, offset arithmetic in Lua (64-bit floating-point numbers) can still represent values up to 2^53 (~9 PB), so this is not a practical limitation.

---

## License

MIT © [NexaRift](https://github.com/NexaRift)

---

<details>
<summary><strong>🇧🇷 Versão em português (clique para expandir)</strong></summary>

<br>

# Lua-Hexdump (Português)

`hexdump.lua` é uma ferramenta de inspeção binária escrita em Lua puro que traz a experiência clássica do `hexdump -C` para qualquer ambiente onde Lua ou LuaJIT esteja disponível — de sistemas embarcados a pipelines de CI. Ele lê arquivos em chunks sequenciais para manter o uso de memória estável independentemente do tamanho do arquivo, formata cada grupo de bytes no layout familiar de offset + hex + ASCII, e expõe um sistema de hooks limpo onde cada estágio do pipeline — abertura do arquivo, formatação das linhas, escrita da saída e o sumário final — pode ser substituído ou estendido sem modificar o código principal. Seja para redirecionar o dump para um arquivo, reformatá-lo como JSON, ler de uma string em memória em vez do disco, ou simplesmente usá-lo como módulo dentro de um projeto Lua maior, os mesmos quatro hooks cobrem tudo. Zero dependências externas, compatível com Lua 5.1 em diante (incluindo LuaJIT), e pronto para uso direto pela linha de comando.

## Índice

- [Visão geral](#visão-geral)
- [Fluxo de processamento](#fluxo-de-processamento)
- [Instalação](#instalação)
- [Uso básico (CLI)](#uso-básico-cli)
- [Uso como módulo](#uso-como-módulo)
- [Hooks de personalização](#hooks-de-personalização)
- [Formato de saída](#formato-de-saída)
- [Decisões de implementação](#decisões-de-implementação)
- [Limitações conhecidas](#limitações-conhecidas)
- [Licença](#licença)

**Características principais:**
- Leitura em blocos de 4 KB → baixo uso de memória
- Acumulação de linhas e flush a cada 1000 linhas → reduz I/O
- Tabela de lookup para conversão byte → hex → elimina `string.format` no hot path
- Reuso de tabelas → evita alocações e pressão no garbage collector
- Totalmente customizável via hooks (abertura, formatação, escrita, sumário)
- Detecta locale do sistema (português ou inglês) para mensagens do sumário

## Fluxo de processamento

O pipeline interno segue estas etapas:

```
Arquivo → leitura em chunks de 4KB → subdivisão em grupos de 16 bytes →
formatação de cada grupo como linha → acúmulo em buffer →
flush a cada 1000 linhas (ou final do arquivo) → escrita no stdout →
exibição de sumário no stderr
```

### Estágios do pipeline

| Estágio | Descrição | Hook correspondente |
|---------|-----------|----------------------|
| Abertura | Abre o arquivo em modo binário (`"rb"`) | `on_open_file` |
| Leitura em blocos | Lê `READ_BUFFER_SIZE` (4096) bytes por vez | interno |
| Divisão em linhas | Quebra o bloco em pedaços de `BYTES_PER_LINE` (16) bytes | interno |
| Formatação | Converte offset e bytes crus em uma linha de texto | `on_format_line` |
| Bufferização | Acumula linhas em uma tabela | interno |
| Flush | Quando `#line_buffer >= FLUSH_INTERVAL` (1000), escreve | `on_write_output` |
| Sumário | Ao final, exibe nome do arquivo, tamanho e tempo | `on_show_summary` |
| Fechamento | Fecha o arquivo | interno |

## Instalação

Sem dependências. Basta obter o arquivo `hexdump.lua`:

```bash
curl -O https://raw.githubusercontent.com/NexaRift/Lua-Hexdump/main/hexdump.lua
```

(Opcional) Torne-o executável no Unix:

```bash
chmod +x hexdump.lua
```

## Uso básico (CLI)

```bash
lua hexdump.lua <arquivo>
luajit hexdump.lua <arquivo>
```

Redirecionar o dump para um arquivo (o sumário ainda aparece no terminal):

```bash
lua hexdump.lua imagem.png > dump.txt
```

Saída de exemplo:

```
00000000  89 50 4E 47 0D 0A 1A 0A  00 00 00 0D 49 48 44 52  |.PNG........IHDR|
00000010  00 00 00 10 00 00 00 10  08 02 00 00 00 90 91 73  |...............s|
...
Arquivo : imagem.png
Tamanho : 1.2 KB (1245 bytes)
Tempo   : 0.002 s
```

## Uso como módulo

```lua
local hexdump = require("hexdump")

-- Dump simples
hexdump.dump("arquivo.bin")

-- Com personalização (exemplo: formato compacto)
hexdump.dump("arquivo.bin", {
    on_format_line = function(offset, bytes)
        local hex = {}
        for i = 1, #bytes do
            hex[i] = string.format("%02X", bytes:byte(i))
        end
        return string.format("%08X: %s", offset, table.concat(hex, " "))
    end
})
```

## Hooks de personalização

Os quatro hooks permitem modificar qualquer parte do pipeline. Eles são passados como um dicionário no segundo argumento de `hexdump.dump()`.

| Hook | Assinatura | Comportamento padrão | Uso típico |
|------|------------|----------------------|-------------|
| `on_open_file` | `(self, filepath) → handle, err` | `io.open(filepath, "rb")` | Abrir de uma string, rede, ou arquivo criptografado |
| `on_format_line` | `(byte_offset, raw_bytes) → string` | `hexdump.formats.classic` | Criar formatos alternativos (JSON, CSV, apenas hex) |
| `on_write_output` | `(self, lines_table) → lines_table` | `io.write(table.concat(lines, "\n") .. "\n")` e retorna tabela limpa | Gravar em arquivo, compactar, enviar via rede |
| `on_show_summary` | `(self, filepath, total_bytes, elapsed_seconds)` | Exibe no stderr (locale-aware) | Suprimir, formatar como JSON, logar |

> **Nota sobre as assinaturas:** `on_open_file`, `on_write_output` e `on_show_summary` são chamados com sintaxe de método (dois-pontos), então o DumperPrototype é sempre passado como primeiro argumento `self`. Use `_` para descartá-lo se não for necessário. `on_format_line` é a exceção — é chamado como função simples (ponto) e não recebe `self`.

### Exemplo: salvar dump em arquivo (em vez de stdout)

```lua
local out = io.open("dump.txt", "w")
hexdump.dump("imagem.png", {
    on_write_output = function(_, lines)  -- _ descarta o self implícito
        out:write(table.concat(lines, "\n"), "\n")
        out:flush()
        for i = 1, #lines do lines[i] = nil end
        return lines
    end
})
out:close()
```

### Exemplo: sumário em JSON no stdout

```lua
hexdump.dump("arquivo.bin", {
    on_show_summary = function(_, path, size, elapsed)  -- _ descarta o self implícito
        local summary = string.format(
            '{"file":"%s","bytes":%d,"time_sec":%.3f}',
            path, size, elapsed
        )
        io.write(summary, "\n")
    end
})
```

### Exemplo: abrir de uma string (útil para testes)

```lua
-- Use uma factory para que os dados sejam capturados via closure.
-- O hook recebe (self, filepath), mas ambos podem ser descartados aqui.
local function make_string_source(content)
    return function(_, _)
        local handle = {
            data = content,
            pos  = 1,
            seek = function(self, whence, offset)
                if whence == "end" then return #self.data end
                if whence == "set" then self.pos = (offset or 0) + 1 end
                return self.pos - 1
            end,
            read = function(self, n)
                local chunk = self.data:sub(self.pos, self.pos + n - 1)
                self.pos = self.pos + #chunk
                return chunk
            end,
            close = function() end
        }
        return handle, nil
    end
end

hexdump.dump("dummy", { on_open_file = make_string_source("\x89PNG\r\n\x1a\x0a...") })
```

## Formato de saída

A função padrão de formatação `hexdump.formats.classic` produz linhas com esta estrutura:

```
<offset>  <hex bytes (16)>  |<ascii>|
```

- **Offset**: 8 dígitos hexadecimais, zero-padded (ex: `00000000`)
- **Hex bytes**: dois caracteres hex por byte; após o 8º byte aparecem dois espaços extras (`"  "`) para separar os dois grupos de 8 bytes
- **ASCII**: caracteres imprimíveis (0x20–0x7E) exibidos literalmente; demais bytes (incluindo newline, tab, bytes > 126) aparecem como `.`

## Decisões de implementação

| Aspecto | Escolha | Justificativa |
|---------|---------|----------------|
| Leitura | `FILE:read(4096)` | Evita carregar o arquivo inteiro na memória; 4 KB é um bom equilíbrio entre chamadas de sistema e overhead |
| Grouping | 16 bytes por linha (`BYTES_PER_LINE`) | Largura padrão no terminal (16 × 3 ≈ 48 colunas + offset e ASCII) |
| Buffer de linhas | `FLUSH_INTERVAL = 1000` | Grava em lote, reduzindo chamadas a `io.write`; 1000 linhas consomem ~60 KB, bem tolerável |
| Conversão byte → hex | Tabela de lookup pré-computada (`HEX_LOOKUP[0..255]`) | Elimina `string.format("%02X", byte)` no loop interno; micro-otimização relevante em arquivos grandes |
| Reuso da tabela de buffer | Preencher com `nil` em vez de `{}` | Evita alocação de nova tabela a cada flush, reduzindo pressão no GC |
| Concatenação | `table.concat` no lugar de `..` em loops | Evita alocações intermediárias de strings; `table.concat` une tudo em uma única alocação |
| Detecção de locale | `LANG`, `LANGUAGE`, `LC_ALL` contendo "pt" | Funciona em qualquer plataforma onde essas variáveis estejam definidas; usa inglês como fallback quando nenhuma delas está definida ou contém `"pt"` (situação comum no Windows por padrão, mas contornável definindo `LANG=pt_BR`) |
| Separação stdout/stderr | Dump → stdout, sumário → stderr | Permite redirecionar o dump (`> arquivo`) sem perder o resumo |

## Limitações conhecidas

- A coluna ASCII exibe apenas caracteres **imprimíveis do ASCII básico (0x20–0x7E)**. Caracteres acentuados, UTF-8 multibyte e a maioria dos controles são representados como `.`.
- O programa não interpreta a codificação do arquivo – trata cada byte individualmente.
- Não suporta todas as opções do `hexdump` tradicional (ex: `-C`, `-b`, `-x`, `-s`, `-n`). Essas funcionalidades podem ser implementadas por meio de hooks, mas não estão incluídas por padrão.
- Em sistemas onde `os.clock()` mede tempo de CPU (e não tempo real), o valor exibido pode diferir ligeiramente do tempo de parede. No entanto, para a maioria das implementações Lua (PUC-Rio e LuaJIT em sistemas POSIX), `os.clock()` retorna tempo de CPU, útil para avaliar performance algorítmica.
- Em arquivos maiores que 2 GB, a aritmética de offset em Lua (números de ponto flutuante de 64 bits) ainda é capaz de representar valores até 2^53 (~9 PB). Portanto, não é uma limitação prática.

## Licença

MIT © [NexaRift](https://github.com/NexaRift)

</details>