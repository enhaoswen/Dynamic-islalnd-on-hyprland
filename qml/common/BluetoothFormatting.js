.pragma library

function cleanText(value) {
    return String(value === undefined || value === null ? "" : value).trim();
}

function normalizedAddress(value) {
    return cleanText(value).toUpperCase().replace(/[-_]/g, ":");
}

function isAddressLike(value, address) {
    const text = cleanText(value);
    if (text.length === 0)
        return false;

    if (/^[0-9A-F]{2}([:_-][0-9A-F]{2}){5}$/i.test(text))
        return true;

    const normalizedDeviceAddress = normalizedAddress(address);
    return normalizedDeviceAddress.length > 0
        && normalizedAddress(text) === normalizedDeviceAddress;
}

function isUsefulName(value, address) {
    const text = cleanText(value);
    if (text.length === 0 || isAddressLike(text, address))
        return false;

    const normalized = text.toLocaleLowerCase();
    return normalized !== "unknown"
        && normalized !== "unknown device"
        && normalized !== "bluetooth device"
        && normalized !== "n/a";
}

function friendlyName(alias, advertisedName, address) {
    // BlueZ Alias is the user-facing name and may contain a user rename. The
    // advertised Name is only the fallback, and can be an address placeholder.
    if (isUsefulName(alias, address))
        return cleanText(alias);
    if (isUsefulName(advertisedName, address))
        return cleanText(advertisedName);
    return "";
}

function typeLabel(icon) {
    switch (cleanText(icon).toLocaleLowerCase()) {
    case "audio-headphones":
        return "Headphones";
    case "audio-headset":
        return "Headset";
    case "audio-card":
    case "audio-speakers":
        return "Audio device";
    case "input-keyboard":
        return "Keyboard";
    case "input-mouse":
        return "Mouse";
    case "input-gaming":
        return "Game controller";
    case "phone":
    case "smartphone":
        return "Phone";
    case "computer":
        return "Computer";
    case "camera-photo":
        return "Camera";
    case "printer":
        return "Printer";
    default:
        return "Unknown device";
    }
}

function displayName(alias, advertisedName, address, icon) {
    const name = friendlyName(alias, advertisedName, address);
    return name.length > 0 ? name : typeLabel(icon);
}

function addressLabel(address) {
    return normalizedAddress(address);
}
