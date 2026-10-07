.pragma library

function playbackNodes(nodes) {
    return nodes.filter(function(node) {
        return node && node.audio && node.isStream && node.isSink;
    });
}

function availableNodes(nodes) {
    return nodes.filter(function(node) {
        return node && node.ready && node.audio;
    });
}

function applicationGroups(nodes) {
    var groups = [];
    var byKey = Object.create(null);

    for (var i = 0; i < nodes.length; ++i) {
        var node = nodes[i];
        if (!node || !node.ready || !node.audio)
            continue;

        var properties = node.properties || {};
        var applicationId = properties["application.id"];
        var applicationName = properties["application.name"];
        var binary = properties["application.process.binary"];
        var identity = applicationId ? "id:" + applicationId
            : binary || applicationName ? JSON.stringify([binary || "", applicationName || ""]) : "";
        var key = identity ? "app:" + identity : "node:" + node.id;
        var label = properties["application.name"]
            || properties["application.process.binary"]
            || node.description || node.name || "Application";

        if (!byKey[key]) {
            byKey[key] = { key: key, label: label, nodes: [] };
            groups.push(byKey[key]);
        }
        byKey[key].nodes.push(node);
    }

    // Names come from PipeWire, not from a predefined list of applications.
    groups.sort(function(left, right) {
        var a = left.label.toLowerCase();
        var b = right.label.toLowerCase();
        return a < b ? -1 : a > b ? 1 : 0;
    });
    return groups;
}

function maximumVolume(nodes) {
    var volume = 0;
    for (var i = 0; i < nodes.length; ++i)
        volume = Math.max(volume, nodes[i].audio.volume);
    return volume;
}

function allMuted(nodes) {
    return nodes.length > 0 && nodes.every(function(node) {
        return node.audio.muted;
    });
}

function toggleMute(nodes) {
    var muted = !allMuted(nodes);
    for (var i = 0; i < nodes.length; ++i)
        nodes[i].audio.muted = muted;
}

function setVolume(nodes, value, maximum, unmute) {
    var volume = Math.max(0, Math.min(maximum, value));
    for (var i = 0; i < nodes.length; ++i) {
        nodes[i].audio.volume = volume;
        if (unmute && volume > 0 && nodes[i].audio.muted)
            nodes[i].audio.muted = false;
    }
}
