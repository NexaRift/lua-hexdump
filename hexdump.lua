local BYTES_PER_LINE = 16
local MIDDLE_SEP_POS = 8
local READ_BUFFER_SIZE = 4096
local FLUSH_INTERVAL = 1000
local ASCII_START = 32
local ASCII_END = 126

local function create_hex_table ()
    local hex_map = {}
    for i = 0, 255 do
        hex_map[i] = string.format("%02X", i)
    end
    return hex_map
end

local HEX = create_hex_table()

local function byte_to_ascii(byte)
    if byte >= ASCII_START and byte <= ASCII_END then
        return string.char(byte)
    end
    return "."
end

local function build_columns(bytes)
    local hex_parts = {}
    local ascii_parts = {}
    local num_bytes = #bytes

    for i = 1, num_bytes do
        local byte = bytes:byte(i)

        hex_parts[#hex_parts + 1] = HEX[byte]
        hex_parts[#hex_parts + 1] = (i == MIDDLE_SEP_POS) and "  " or " "

        ascii_parts[#ascii_parts + 1] = byte_to_ascii(byte)
    end

    for i = num_bytes + 1, BYTES_PER_LINE do
        hex_parts[#hex_parts + 1] = "   "
        if i == MIDDLE_SEP_POS then
            hex_parts[#hex_parts + 1] = " "
        end
        ascii_parts[#ascii_parts + 1] = " "
    end

    return table.concat(hex_parts), table.concat(ascii_parts)
end

local function format_line(offset, bytes)
    local hex_str, ascii_str = build_columns(bytes)
    return string.format("%08X  %s  |%s|", offset, hex_str, ascii_str)
end

local function flush_and_reset(lines)
    io.write(table.concat(lines, "\n"), "\n")
    return {}
end

local function format_size(bytes)
    if bytes >= 1024 * 1024 then
        return string.format("%.1f MB", bytes / (1024 * 1024))
    elseif bytes >= 1024 then
        return string.format("%.1f KB", bytes / 1024)
    else
        return string.format("%d B", bytes)
    end
end

local function get_locale()
    local lang = os.getenv("LANG") or os.getenv("LANGUAGE") or os.getenv("LC_ALL") or ""
    return lang:lower():find("pt") and "pt" or "en"
end

local MESSAGES = {
    en = {
        file    = "File   ",
        size    = "Size   ",
        time    = "Time   ",
        error   = "Error opening '%s': %s\n",
        usage   = "Usage: lua hexdump.lua <file>\n",
        example = "Example: lua hexdump.lua image.png\n",
    },
    pt = {
        file    = "Arquivo",
        size    = "Tamanho",
        time    = "Tempo  ",
        error   = "Erro ao abrir '%s': %s\n",
        usage   = "Uso: lua hexdump.lua <arquivo>\n",
        example = "Exemplo: lua hexdump.lua imagem.png\n",
    }
}

local LOCALE = get_locale()
local MSG = MESSAGES[LOCALE]

local function show_summary(filepath, size, time)
    io.stderr:write(string.format(
        "%s : %s\n"       ..
        "%s : %s (%d bytes)\n" ..
        "%s : %.3f s\n",
        MSG.file, filepath,
        MSG.size, format_size(size), size,
        MSG.time, time
    ))
    io.stderr:flush()
end

local function hexdump(filepath)
    local file, err = io.open(filepath, "rb")
    if not file then
        io.stderr:write(string.format(MSG.error, filepath, err))
        return false
    end

    local total_size = file:seek("end")
    file:seek("set", 0)

    local start_time = os.clock()
    local offset = 0
    local lines = {}

    while true do
        local chunk = file:read(READ_BUFFER_SIZE)
        if not chunk then break end

        for i = 1, #chunk, BYTES_PER_LINE do
            local bytes = chunk:sub(i, i + BYTES_PER_LINE - 1)
            lines[#lines + 1] = format_line(offset, bytes)
            offset = offset + #bytes
        end

        if #lines >= FLUSH_INTERVAL then
            lines = flush_and_reset(lines)
        end
    end

    if #lines > 0 then
        flush_and_reset(lines)
    end

    show_summary(filepath, total_size, os.clock() - start_time)

    file:close()
    return true
end

local filepath = arg and arg[1]

if not filepath then
    io.stderr:write(MSG.usage)
    io.stderr:write(MSG.example)
    os.exit(1)
end

if not hexdump(filepath) then
    os.exit(1)
end