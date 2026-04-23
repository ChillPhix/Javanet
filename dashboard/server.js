const express = require('express');
const path = require('path');
const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json({ limit: '1mb' }));

// ============================================================
// State — holds the latest data from the mainframe
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

// ============================================================
// API Endpoints
// ============================================================

// Mainframe POSTs status updates here
app.post('/api/status', (req, res) => {
    const data = req.body;
    if (data) {
        facilityState = {
            ...facilityState,
            ...data,
            lastUpdate: new Date().toISOString(),
        };
    }
    res.json({ ok: true });
});

// Dashboard GETs current state
app.get('/api/status', (req, res) => {
    res.json(facilityState);
});

// Mainframe POSTs log entries
app.post('/api/log', (req, res) => {
    const entry = req.body;
    if (entry && entry.message) {
        facilityState.logs.unshift({
            time: new Date().toISOString(),
            ...entry,
        });
        // Keep last 200 logs
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
// Serve dashboard HTML
// ============================================================

app.use(express.static(path.join(__dirname, 'public')));

app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// ============================================================
// Start
// ============================================================

app.listen(PORT, () => {
    console.log(`Javanet Dashboard running on port ${PORT}`);
});
