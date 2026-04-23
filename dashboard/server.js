const express = require('express');
const path = require('path');
const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json({ limit: '1mb' }));

// ============================================================
// State
// ============================================================

let facilityState = {
    lastUpdate: null,
    identity: { name: "JAVANET", subtitle: "AWAITING CONNECTION" },
    state: "offline",
    zones: [],
    breaches: [],
    terminals: [],
    personnel: [],
    logs: [],
    alerts: [],
    infections: [],
};

// Command queue — web dashboard pushes commands, mainframe polls for them
let commandQueue = [];

// ============================================================
// API Endpoints
// ============================================================

// Mainframe POSTs status updates — returns pending commands
app.post('/api/status', (req, res) => {
    const data = req.body;
    if (data) {
        facilityState = {
            ...facilityState,
            ...data,
            lastUpdate: new Date().toISOString(),
        };
    }
    // Return any pending commands to the mainframe
    const commands = [...commandQueue];
    commandQueue = [];
    res.json({ ok: true, commands });
});

// Dashboard GETs current state
app.get('/api/status', (req, res) => {
    res.json(facilityState);
});

// Dashboard POSTs a command for the mainframe to execute
app.post('/api/command', (req, res) => {
    const cmd = req.body;
    if (cmd && cmd.action) {
        commandQueue.push({
            ...cmd,
            time: new Date().toISOString(),
        });
        res.json({ ok: true, queued: commandQueue.length });
    } else {
        res.status(400).json({ error: "Missing action" });
    }
});

// Mainframe POSTs log entries
app.post('/api/log', (req, res) => {
    const entry = req.body;
    if (entry && entry.message) {
        facilityState.logs.unshift({
            time: new Date().toISOString(),
            ...entry,
        });
        if (facilityState.logs.length > 200) {
            facilityState.logs = facilityState.logs.slice(0, 200);
        }
    }
    res.json({ ok: true });
});

// Mainframe POSTs alerts
app.post('/api/alert', (req, res) => {
    const alert = req.body;
    if (alert && alert.message) {
        facilityState.alerts.unshift({
            time: new Date().toISOString(),
            ...alert,
        });
        if (facilityState.alerts.length > 100) {
            facilityState.alerts = facilityState.alerts.slice(0, 100);
        }
    }
    res.json({ ok: true });
});

// ============================================================
// Serve dashboard
// ============================================================

app.use(express.static(path.join(__dirname, 'public')));

app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, () => {
    console.log(`Javanet Dashboard running on port ${PORT}`);
});
