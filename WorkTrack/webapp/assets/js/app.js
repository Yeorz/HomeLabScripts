/* WorkTrack — app.js */
'use strict';

/* ── Utilities ─────────────────────────────────────────────── */
function escHtml(str) {
    const d = document.createElement('div');
    d.textContent = str ?? '';
    return d.innerHTML;
}

function showToast(msg, type = 'info', duration = 3000) {
    const c = document.getElementById('toastContainer');
    if (!c) return;
    const t = document.createElement('div');
    t.className = `toast ${type}`;
    t.textContent = msg;
    c.appendChild(t);
    setTimeout(() => { t.style.opacity = '0'; t.style.transition = 'opacity 0.3s'; setTimeout(() => t.remove(), 300); }, duration);
}

function formatDur(secs) {
    secs = parseInt(secs) || 0;
    const h = Math.floor(secs / 3600);
    const m = Math.floor((secs % 3600) / 60);
    const s = secs % 60;
    if (h) return `${h}:${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')}`;
    return `${m}:${String(s).padStart(2,'0')}`;
}

function parseDuration(str) {
    if (!str) return null;
    const parts = str.split(':').map(Number);
    if (parts.length === 3) return parts[0]*3600 + parts[1]*60 + parts[2];
    if (parts.length === 2) return parts[0]*60 + parts[1];
    return parseInt(str) || null;
}

async function apiFetch(url, opts = {}) {
    try {
        const res  = await fetch(url, { headers: {'Content-Type': 'application/json'}, ...opts });
        const data = await res.json();
        if (data.error) throw new Error(data.error);
        return data;
    } catch (err) {
        showToast(err.message || 'Netwerk fout', 'error');
        throw err;
    }
}

/* ── Mobile nav ────────────────────────────────────────────── */
const navToggle = document.getElementById('navToggle');
const navMobile = document.getElementById('navMobile');
if (navToggle && navMobile) {
    navToggle.addEventListener('click', () => {
        navMobile.classList.toggle('open');
        navToggle.classList.toggle('open');
    });
    document.addEventListener('click', e => {
        if (!navToggle.contains(e.target) && !navMobile.contains(e.target)) {
            navMobile.classList.remove('open');
        }
    });
}

/* ── Workout page ──────────────────────────────────────────── */
if (typeof WORKOUT_ID !== 'undefined') {
    initWorkoutPage();
}

function initWorkoutPage() {
    // Timer
    if (!IS_FINISHED) {
        startTimer();
    }
    updateSummary();

    // Workout name auto-save
    const nameInput = document.getElementById('workoutName');
    if (nameInput) {
        let nameTimer;
        nameInput.addEventListener('input', () => {
            clearTimeout(nameTimer);
            nameTimer = setTimeout(() => {
                apiFetch('/webapp/api/workouts.php?action=update', {
                    method: 'POST',
                    body: JSON.stringify({ action: 'update', id: WORKOUT_ID, name: nameInput.value })
                });
            }, 600);
        });
    }

    // Finish button
    const btnFinish = document.getElementById('btnFinish');
    if (btnFinish) {
        btnFinish.addEventListener('click', async () => {
            if (!confirm('Workout afronden?')) return;
            await apiFetch('/webapp/api/workouts.php?action=finish', {
                method: 'POST',
                body: JSON.stringify({ action: 'finish', id: WORKOUT_ID })
            });
            showToast('Workout afgerond! 💪', 'success');
            setTimeout(() => location.href = '/webapp/history.php', 1200);
        });
    }

    // Add exercise button
    const btnAdd = document.getElementById('btnAddExercise');
    if (btnAdd) {
        btnAdd.addEventListener('click', () => openExerciseModal());
    }

    // Exercise search
    const searchInput = document.getElementById('exerciseSearch');
    if (searchInput) {
        let searchTimer;
        searchInput.addEventListener('input', () => {
            clearTimeout(searchTimer);
            searchTimer = setTimeout(() => searchExercises(searchInput.value), 250);
        });
        // Load all on focus if empty
        searchInput.addEventListener('focus', () => {
            if (!searchInput.value) searchExercises('');
        });
    }

    // Close modal on backdrop click
    const modal = document.getElementById('exerciseModal');
    if (modal) {
        modal.addEventListener('click', e => {
            if (e.target === modal) closeExerciseModal();
        });
    }
}

/* ── Timer ─────────────────────────────────────────────────── */
function startTimer() {
    const el = document.getElementById('workoutTimer');
    if (!el) return;
    function tick() {
        const elapsed = Math.floor((Date.now() - START_TIME.getTime()) / 1000);
        el.textContent = formatDur(elapsed);
    }
    tick();
    setInterval(tick, 1000);
}

/* ── Live summary ──────────────────────────────────────────── */
function updateSummary() {
    const blocks = document.querySelectorAll('.exercise-block');
    let totalSets = 0, totalVol = 0;

    blocks.forEach(block => {
        const rows = block.querySelectorAll('.set-row');
        rows.forEach(row => {
            if (row.classList.contains('is-warmup')) return;
            totalSets++;
            const inputs = row.querySelectorAll('.set-input');
            if (block.dataset.category !== 'cardio' && inputs.length >= 2) {
                const w = parseFloat(inputs[0].value) || 0;
                const r = parseInt(inputs[1].value) || 0;
                let wKg = w;
                if (typeof UNIT_SYSTEM !== 'undefined' && UNIT_SYSTEM === 'imperial') {
                    wKg = w / 2.20462;
                }
                totalVol += wKg * r;
            }
        });
    });

    const sumEx  = document.getElementById('sumExercises');
    const sumSets= document.getElementById('sumSets');
    const sumVol = document.getElementById('sumVolume');
    const unit   = typeof UNIT_SYSTEM !== 'undefined' ? UNIT_SYSTEM : 'metric';

    if (sumEx)   sumEx.textContent   = blocks.length;
    if (sumSets) sumSets.textContent = totalSets;
    if (sumVol) {
        if (unit === 'imperial') {
            sumVol.textContent = Math.round(totalVol * 2.20462).toLocaleString() + ' lbs';
        } else {
            sumVol.textContent = Math.round(totalVol).toLocaleString() + ' kg';
        }
    }
}

/* ── Add set row ───────────────────────────────────────────── */
function addSetRow(weId, btn, isWarmup = false) {
    const block    = document.querySelector(`.exercise-block[data-we-id="${weId}"]`);
    const table    = block.querySelector('.sets-table');
    const isCardio = block.dataset.category === 'cardio';
    const unit     = typeof UNIT_SYSTEM !== 'undefined' ? UNIT_SYSTEM : 'metric';
    const wUnit    = unit === 'imperial' ? 'lbs' : 'kg';
    const dUnit    = unit === 'imperial' ? 'mi'  : 'km';

    // Count existing non-warmup sets for numbering
    const allRows = table.querySelectorAll('.set-row:not(.is-warmup)');
    const warmups = table.querySelectorAll('.set-row.is-warmup');
    const setNum  = isWarmup ? 0 : (allRows.length + 1);

    const row = document.createElement('div');
    row.className = `set-row ${isCardio ? 'cardio-cols' : ''} ${isWarmup ? 'is-warmup' : ''}`;
    row.dataset.setNum = setNum;

    const numLabel = isWarmup ? 'W' : setNum;

    if (isCardio) {
        row.innerHTML = `
            <div class="set-num">${numLabel}</div>
            <input class="set-input" type="text" placeholder="mm:ss"
                   onchange="saveSet(${weId}, ${setNum}, this.closest('.set-row'))">
            <input class="set-input" type="number" step="0.01" placeholder="${dUnit}"
                   onchange="saveSet(${weId}, ${setNum}, this.closest('.set-row'))">
            <button class="btn-icon" onclick="removeSet(${weId}, ${setNum}, this)" title="Verwijder set">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M18 6L6 18M6 6l12 12"/></svg>
            </button>`;
    } else {
        // Copy previous set values for convenience
        const prevRows = table.querySelectorAll('.set-row:not(.is-warmup)');
        let prevW = '', prevR = '';
        if (prevRows.length > 0 && !isWarmup) {
            const lastRow = prevRows[prevRows.length - 1];
            const ins = lastRow.querySelectorAll('.set-input');
            if (ins[0]) prevW = ins[0].value;
            if (ins[1]) prevR = ins[1].value;
        }
        row.innerHTML = `
            <div class="set-num">${numLabel}</div>
            <input class="set-input" type="number" step="0.5" placeholder="${wUnit}" value="${escHtml(prevW)}"
                   onchange="saveSet(${weId}, ${setNum}, this.closest('.set-row'))">
            <input class="set-input" type="number" placeholder="reps" value="${escHtml(prevR)}"
                   onchange="saveSet(${weId}, ${setNum}, this.closest('.set-row'))">
            <input class="set-input col-rpe" type="number" min="1" max="10" placeholder="RPE"
                   onchange="saveSet(${weId}, ${setNum}, this.closest('.set-row'))">
            <button class="btn-icon" onclick="removeSet(${weId}, ${setNum}, this)" title="Verwijder set">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M18 6L6 18M6 6l12 12"/></svg>
            </button>`;
    }

    // Insert before the footer
    const footer = block.querySelector('.set-footer');
    table.insertBefore(row, footer);
    row.querySelectorAll('.set-input')[0]?.focus();
    updateSummary();
}

/* ── Save set ──────────────────────────────────────────────── */
async function saveSet(weId, setNumber, row) {
    const isCardio = row.closest('.exercise-block')?.dataset.category === 'cardio';
    const inputs   = row.querySelectorAll('.set-input');
    const isWarmup = row.classList.contains('is-warmup') ? 1 : 0;
    const unit     = typeof UNIT_SYSTEM !== 'undefined' ? UNIT_SYSTEM : 'metric';

    const payload = { action: 'save_set', we_id: weId, set_number: setNumber, is_warmup: isWarmup };

    if (isCardio) {
        payload.duration_seconds = parseDuration(inputs[0]?.value) ?? null;
        const dist = parseFloat(inputs[1]?.value);
        if (!isNaN(dist)) {
            payload.distance_km = unit === 'imperial' ? dist / 0.621371 : dist;
        }
    } else {
        const w = parseFloat(inputs[0]?.value);
        if (!isNaN(w)) {
            payload.weight_kg = unit === 'imperial' ? w / 2.20462 : w;
        }
        const r = parseInt(inputs[1]?.value);
        if (!isNaN(r)) payload.reps = r;
        const rpe = parseInt(inputs[2]?.value);
        if (!isNaN(rpe) && rpe >= 1 && rpe <= 10) payload.rpe = rpe;
    }

    try {
        const data = await apiFetch('/webapp/api/workouts.php?action=save_set', {
            method: 'POST',
            body: JSON.stringify(payload)
        });
        if (data.id) row.dataset.setId = data.id;
        updateSummary();
    } catch { /* toast shown in apiFetch */ }
}

/* ── Remove set ────────────────────────────────────────────── */
async function removeSet(weId, setNum, btn) {
    const row   = btn.closest('.set-row');
    const setId = row?.dataset.setId ? parseInt(row.dataset.setId) : null;
    await apiFetch('/webapp/api/workouts.php?action=remove_set', {
        method: 'POST',
        body: JSON.stringify({ action: 'remove_set', set_id: setId, we_id: weId, set_number: setNum })
    });
    row?.remove();
    renumberSets(weId);
    updateSummary();
}

function renumberSets(weId) {
    const block = document.querySelector(`.exercise-block[data-we-id="${weId}"]`);
    if (!block) return;
    let n = 1;
    block.querySelectorAll('.set-row:not(.is-warmup) .set-num').forEach(el => {
        el.textContent = n++;
    });
}

/* ── Remove exercise ────────────────────────────────────────── */
async function removeExercise(weId) {
    if (!confirm('Oefening verwijderen inclusief alle sets?')) return;
    await apiFetch('/webapp/api/workouts.php?action=remove_exercise', {
        method: 'POST',
        body: JSON.stringify({ action: 'remove_exercise', we_id: weId })
    });
    document.querySelector(`.exercise-block[data-we-id="${weId}"]`)?.remove();
    updateSummary();
}

/* ── Exercise search modal ───────────────────────────────────── */
function openExerciseModal() {
    const modal = document.getElementById('exerciseModal');
    if (!modal) return;
    modal.classList.add('open');
    const inp = document.getElementById('exerciseSearch');
    if (inp) { inp.value = ''; inp.focus(); searchExercises(''); }
}

function closeExerciseModal() {
    document.getElementById('exerciseModal')?.classList.remove('open');
}

async function searchExercises(q) {
    const results = document.getElementById('exerciseResults');
    if (!results) return;

    const url = '/webapp/api/exercises.php?action=search&q=' + encodeURIComponent(q);
    let exercises;
    try {
        exercises = await fetch(url).then(r => r.json());
    } catch {
        results.innerHTML = '<p class="text-muted text-sm" style="padding:1rem">Fout bij laden.</p>';
        return;
    }

    if (!exercises.length) {
        const escapedQ = escHtml(q);
        results.innerHTML = `
            <div style="padding:0.75rem">
                <p class="text-muted text-sm" style="margin-bottom:0.75rem">Geen oefeningen gevonden.</p>
                ${q ? `<button class="btn btn-ghost btn-sm btn-block"
                    onclick="addCustomExercise('${escapedQ.replace(/'/g,"\\'")}')">
                    + "${escapedQ}" toevoegen als eigen oefening
                </button>` : ''}
            </div>`;
        return;
    }

    // Group by muscle group
    const byGroup = {};
    exercises.forEach(e => {
        const g = e.muscle_group || 'Overig';
        (byGroup[g] = byGroup[g] || []).push(e);
    });

    const equipLabel = {
        barbell:'Halter', dumbbell:'Dumbbell', machine:'Machine', cable:'Kabel',
        bodyweight:'Lichaamsgewicht', kettlebell:'Kettlebell', bands:'Weerstandsbanden',
        cardio:'Cardio', overig:''
    };

    let html = '';
    for (const [group, exs] of Object.entries(byGroup)) {
        html += `<div class="exercise-group-header">${escHtml(group)}</div>`;
        exs.forEach(e => {
            const equip = equipLabel[e.equipment] || '';
            const meta  = [e.muscle_group, equip].filter(Boolean).join(' · ');
            html += `
            <div class="exercise-option" onclick="pickExercise(${e.id}, '${escHtml(e.name_nl).replace(/'/g,"\\'")}', '${e.category}', '${e.muscle_group || ''}', '${equip}')">
                <div>
                    <div class="exercise-option-name">${escHtml(e.name_nl)}</div>
                    <div class="exercise-option-meta">${escHtml(meta)}</div>
                </div>
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--text-3)" stroke-width="2"><path d="M12 5v14M5 12h14"/></svg>
            </div>`;
        });
    }

    // Option to add custom if typed something
    if (q) {
        html += `<div style="padding:0.75rem;border-top:1px solid var(--border)">
            <button class="btn btn-ghost btn-sm btn-block"
                onclick="addCustomExercise('${escHtml(q).replace(/'/g,"\\'")}')">
                + "${escHtml(q)}" toevoegen als eigen oefening
            </button></div>`;
    }

    results.innerHTML = html;
}

async function pickExercise(exerciseId, name, category, muscleGroup, equip) {
    closeExerciseModal();
    try {
        const data = await apiFetch('/webapp/api/workouts.php?action=add_exercise', {
            method: 'POST',
            body: JSON.stringify({
                action: 'add_exercise',
                workout_id: WORKOUT_ID,
                exercise_id: exerciseId
            })
        });
        appendExerciseBlock(data);
    } catch { /* toast shown */ }
}

async function addCustomExercise(name) {
    closeExerciseModal();
    try {
        const data = await apiFetch('/webapp/api/workouts.php?action=add_exercise', {
            method: 'POST',
            body: JSON.stringify({
                action: 'add_exercise',
                workout_id: WORKOUT_ID,
                custom_name: name
            })
        });
        appendExerciseBlock(data);
    } catch { /* toast shown */ }
}

function appendExerciseBlock(ex) {
    const container = document.getElementById('exerciseContainer');
    if (!container) return;

    const unit     = typeof UNIT_SYSTEM !== 'undefined' ? UNIT_SYSTEM : 'metric';
    const wUnit    = unit === 'imperial' ? 'lbs' : 'kg';
    const dUnit    = unit === 'imperial' ? 'mi'  : 'km';
    const isCardio = ex.category === 'cardio';
    const meta     = [ex.muscle_group, ex.equipment_label || ''].filter(Boolean).join(' · ');

    const block = document.createElement('div');
    block.className = 'exercise-block';
    block.dataset.weId     = ex.id;
    block.dataset.category = ex.category || 'kracht';

    block.innerHTML = `
        <div class="exercise-header">
            <div class="exercise-header-info">
                <div class="exercise-name">${escHtml(ex.name)}</div>
                ${meta ? `<div class="exercise-meta">${escHtml(meta)}</div>` : ''}
            </div>
            <button class="btn-icon" onclick="removeExercise(${ex.id})" title="Verwijder oefening">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6L6 18M6 6l12 12"/></svg>
            </button>
        </div>
        <div class="sets-table">
            <div class="sets-header ${isCardio ? 'cardio-cols' : ''}">
                <span>Set</span>
                ${isCardio
                    ? `<span>Tijd</span><span>Afstand (${dUnit})</span>`
                    : `<span>Gewicht (${wUnit})</span><span>Reps</span><span class="col-rpe">RPE</span>`}
                <span></span>
            </div>
        </div>
        <div class="set-footer">
            <button class="btn btn-ghost btn-sm" onclick="addSetRow(${ex.id}, this)">+ Set toevoegen</button>
            <button class="btn btn-sm" style="background:rgba(255,178,63,0.12);color:var(--warning);border:1px solid rgba(255,178,63,0.25)"
                    onclick="addSetRow(${ex.id}, this, true)">+ Warming-up</button>
        </div>`;

    // Insert before the "Add exercise" button
    const addBtn = document.getElementById('btnAddExercise');
    container.insertBefore(block, addBtn);

    // Auto-add first set
    addSetRow(ex.id, null);
    updateSummary();
}

/* ── History detail helpers ──────────────────────────────────── */
if (typeof toggleDetail === 'undefined') {
    window.toggleDetail = function() {};
}
