.pragma library

function context(raw) {
    try {
        const value = JSON.parse(raw || "{}")
        return value && typeof value === "object" && !Array.isArray(value) ? value : {}
    } catch (error) {
        return {}
    }
}

function finite(value, fallback) {
    return typeof value === "number" && Number.isFinite(value) ? value : fallback
}

function left(center, width, screenWidth, gap) {
    return Math.round(Math.max(gap, Math.min(center - width / 2, screenWidth - width - gap)))
}
