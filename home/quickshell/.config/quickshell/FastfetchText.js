.pragma library

function ghosttySettings(config, defaults) {
    var settings = {
        family: "",
        pointSize: 0,
        foreground: "",
        palette: []
    };
    applyGhosttySettings(settings, defaults || "");
    applyGhosttySettings(settings, config || "");
    return settings;
}

function applyGhosttySettings(settings, config) {
    var familySelected = false;
    var lines = config.split("\n");

    for (var i = 0; i < lines.length; ++i) {
        var match = /^\s*([\w-]+)\s*=\s*(.*?)\s*$/.exec(lines[i]);
        if (!match)
            continue;

        var key = match[1];
        var value = match[2].replace(/^"|"$/g, "");
        if (key === "font-family") {
            if (!value) {
                // Ghostty serializes its embedded JetBrains Mono as an empty family.
                settings.family = "JetBrains Mono";
                familySelected = false;
            } else if (!familySelected) {
                settings.family = value;
                familySelected = true;
            }
        } else if (key === "font-size" && Number(value) > 0) {
            settings.pointSize = Number(value);
        } else if (key === "foreground" && /^#?[0-9a-f]{6}$/i.test(value)) {
            settings.foreground = "#" + value.replace(/^#/, "");
        } else if (key === "palette") {
            var color = /^(\d+)\s*=\s*#?([0-9a-f]{6})$/i.exec(value);
            if (color && Number(color[1]) < 256)
                settings.palette[Number(color[1])] = "#" + color[2];
        }
    }

}

function escapeHtml(text) {
    return text.replace(/&/g, "&amp;").replace(/</g, "&lt;")
        .replace(/>/g, "&gt;").replace(/"/g, "&quot;")
        .replace(/ /g, "&nbsp;");
}

function indexedColor(index, palette, foreground) {
    if (palette[index])
        return palette[index];
    if (index < 16)
        return foreground;
    if (index >= 232) {
        var gray = 8 + (index - 232) * 10;
        return "#" + hexByte(gray) + hexByte(gray) + hexByte(gray);
    }
    var levels = [0, 95, 135, 175, 215, 255];
    index -= 16;
    return "#" + hexByte(levels[Math.floor(index / 36)])
        + hexByte(levels[Math.floor(index / 6) % 6])
        + hexByte(levels[index % 6]);
}

function hexByte(value) {
    return ("0" + Math.max(0, Math.min(255, value)).toString(16)).slice(-2);
}

// Fastfetch draws the logo first, then moves back up to print the fields.
// Preserve these cursor movements instead of merely removing ANSI escapes.
function render(output, settings, fallbackForeground) {
    // OSC hyperlinks contain metadata, not visible text. Keep the label between them.
    output = output.replace(/\x1b\][\s\S]*?(?:\x07|\x1b\\)/g, "");
    var rows = [];
    var row = 0;
    var column = 0;
    var foreground = settings.foreground || fallbackForeground;
    var color = foreground;
    var bold = false;
    var tokens = /\x1b\[([0-9;?]*)([A-Za-z])|([\s\S])/g;
    var token;

    while ((token = tokens.exec(output)) !== null) {
        if (token[3] !== undefined) {
            var character = token[3];
            if (character === "\n") {
                ++row;
                column = 0;
            } else if (character === "\r") {
                column = 0;
            } else if (character === "\t") {
                column += 8 - column % 8;
            } else if (character === "\b") {
                column = Math.max(0, column - 1);
            } else if (character.charCodeAt(0) >= 32) {
                // A UTF-16 surrogate pair occupies one cell for this output.
                var code = character.charCodeAt(0);
                if (code >= 0xd800 && code <= 0xdbff && tokens.lastIndex < output.length) {
                    var next = output.charCodeAt(tokens.lastIndex);
                    if (next >= 0xdc00 && next <= 0xdfff)
                        character += output.charAt(tokens.lastIndex++);
                }
                if (!rows[row])
                    rows[row] = [];
                rows[row][column++] = { text: character, color: color, bold: bold };
            }
            continue;
        }

        var values = token[1].split(";").map(function(value) { return Number(value) || 0; });
        var amount = values[0] || 1;
        var operation = token[2];
        if (operation === "A") row = Math.max(0, row - amount);
        else if (operation === "B") row += amount;
        else if (operation === "C") column += amount;
        else if (operation === "D") column = Math.max(0, column - amount);
        else if (operation === "G") column = amount - 1;
        else if (operation === "H" || operation === "f") {
            row = amount - 1;
            column = (values[1] || 1) - 1;
        } else if (operation === "m") {
            for (var i = 0; i < values.length; ++i) {
                var value = values[i];
                if (value === 0) { color = foreground; bold = false; }
                else if (value === 1) bold = true;
                else if (value === 22) bold = false;
                else if (value === 39) color = foreground;
                else if (value >= 30 && value <= 37) color = settings.palette[value - 30] || foreground;
                else if (value >= 90 && value <= 97) color = settings.palette[value - 90 + 8] || foreground;
                else if (value === 38 && values[i + 1] === 5) {
                    color = indexedColor(values[i + 2], settings.palette, foreground);
                    i += 2;
                } else if (value === 38 && values[i + 1] === 2) {
                    color = "#" + hexByte(values[i + 2]) + hexByte(values[i + 3]) + hexByte(values[i + 4]);
                    i += 4;
                }
            }
        }
    }

    var plainLines = [];
    var styledLines = [];
    for (var y = 0; y < rows.length; ++y) {
        var cells = rows[y] || [];
        var end = cells.length;
        while (end > 0 && (!cells[end - 1] || cells[end - 1].text === " "))
            --end;
        var plain = "";
        var styled = "";
        var previousStyle = "";
        for (var x = 0; x < end; ++x) {
            var cell = cells[x] || { text: " ", color: foreground, bold: false };
            var style = cell.color + ":" + cell.bold;
            if (style !== previousStyle) {
                if (previousStyle) {
                    if (previousStyle.slice(-4) === "true")
                        styled += "</b>";
                    styled += "</font>";
                }
                styled += '<font color="' + cell.color + '">';
                if (cell.bold)
                    styled += "<b>";
                previousStyle = style;
            }
            plain += cell.text;
            styled += escapeHtml(cell.text);
        }
        if (previousStyle) {
            if (previousStyle.slice(-4) === "true")
                styled += "</b>";
            styled += "</font>";
        }
        plainLines.push(plain);
        styledLines.push(styled);
    }
    while (plainLines.length > 0 && plainLines[plainLines.length - 1] === "") {
        plainLines.pop();
        styledLines.pop();
    }
    return { plain: plainLines.join("\n"), styled: styledLines.join("<br>") };
}
