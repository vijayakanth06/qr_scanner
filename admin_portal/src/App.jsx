import { useEffect, useMemo, useState } from 'react';
import {
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
} from 'firebase/auth';
import { get, onValue, ref, runTransaction, update } from 'firebase/database';
import * as XLSX from 'xlsx';

import { auth, db } from './firebase';

const requiredEnvVars = [
  'VITE_FIREBASE_API_KEY',
  'VITE_FIREBASE_DATABASE_URL',
  'VITE_FIREBASE_PROJECT_ID',
];
const missing = requiredEnvVars.filter((k) => !import.meta.env[k]);
if (missing.length > 0) {
  throw new Error(
    `Missing required environment variables: ${missing.join(', ')}\n` +
      'Copy admin_portal/.env.example to .env.local and fill in values.',
  );
}

const COLLEGES = [
  { id: 'kec', name: 'Kongu Engineering College', location: 'Erode, TN' },
  { id: 'psg', name: 'PSG College of Technology', location: 'Coimbatore, TN' },
  { id: 'cit', name: 'Coimbatore Institute of Technology', location: 'Coimbatore, TN' },
];

const versionToKey = (v) => v ? v.replace(/\./g, '_') : v;

function compareVersionsDescending(a, b) {
  const toTuple = (v) => {
    const [majorRaw, patchRaw] = String(v ?? '').split('.');
    const major = Number.parseInt(majorRaw ?? '0', 10) || 0;
    const patch = Number.parseInt(patchRaw ?? '0', 10) || 0;
    return [major, patch];
  };
  const [aMajor, aPatch] = toTuple(a);
  const [bMajor, bPatch] = toTuple(b);
  if (aMajor !== bMajor) return bMajor - aMajor;
  return bPatch - aPatch;
}

const COLUMN_CONFIG = [
  { key: 'rollNo', label: 'Roll No', required: true },
  { key: 'name', label: 'Name', required: true },
  { key: 'studentMobileNo', label: 'Student Mobile', required: true },
  { key: 'branch', label: 'Department', required: true },
  { key: 'yearOfStudy', label: 'Year', required: true },
  { key: 'section', label: 'Section', required: true },
  { key: 'gender', label: 'Gender' },
  { key: 'hostellerDayScholar', label: 'Hosteller/Day Scholar' },
  { key: 'parentMobileNo', label: 'Parent Mobile' },
];

const YEAR_OPTIONS = ['I', 'II', 'III', 'IV'];
const GENDER_OPTIONS = ['', 'MALE', 'FEMALE'];
const RESIDENCE_OPTIONS = ['', 'HOSTELLER', 'DAY SCHOLAR'];

function sanitizeRollNo(value) {
  return String(value ?? '').trim().toUpperCase();
}

function normalizeYear(value) {
  const normalized = String(value ?? '').trim().toUpperCase();
  if (YEAR_OPTIONS.includes(normalized)) return normalized;
  if (normalized === '1') return 'I';
  if (normalized === '2') return 'II';
  if (normalized === '3') return 'III';
  if (normalized === '4') return 'IV';
  return normalized;
}

function normalizeStudent(raw, fallback = {}) {
  const rollNo = sanitizeRollNo(raw.rollNo ?? raw.rollNumber ?? raw.id);
  return {
    _sourceRoll: sanitizeRollNo(raw._sourceRoll ?? rollNo),
    rollNo,
    name: String(raw.name ?? '').trim(),
    studentMobileNo: String(raw.studentMobileNo ?? raw.mobileNumber ?? raw.phone ?? '').trim(),
    branch: String(raw.branch ?? fallback.branch ?? '').trim().toUpperCase(),
    yearOfStudy: normalizeYear(raw.yearOfStudy ?? fallback.yearOfStudy ?? ''),
    section: String(raw.section ?? fallback.section ?? '').trim().toUpperCase(),
    gender: String(raw.gender ?? '').trim().toUpperCase(),
    hostellerDayScholar: String(raw.hostellerDayScholar ?? raw.residence ?? '').trim().toUpperCase(),
    parentMobileNo: String(raw.parentMobileNo ?? '').trim(),
    updatedAt: Date.now(),
    updatedBy: auth.currentUser?.email ?? 'unknown',
  };
}

function parseRowsFromJson(rows, fallback) {
  return rows
    .map((row) => {
      const keyMap = Object.keys(row).reduce((acc, key) => {
        acc[key.replace(/\s+/g, '').toLowerCase()] = row[key];
        return acc;
      }, {});
      return normalizeStudent(
        {
          rollNo: keyMap.rollno ?? keyMap.rollnumber,
          name: keyMap.name,
          studentMobileNo: keyMap.studentmobileno ?? keyMap.mobileno ?? keyMap.mobile,
          branch: keyMap.branch ?? keyMap.department,
          yearOfStudy: keyMap.yearofstudy ?? keyMap.year,
          section: keyMap.section,
          gender: keyMap.gender,
          hostellerDayScholar: keyMap.hostellerdayscholar ?? keyMap.residence,
          parentMobileNo: keyMap.parentmobileno,
        },
        fallback,
      );
    })
    .filter((row) => row.rollNo);
}

function toPersistedStudentShape(student) {
  return {
    rollNo: sanitizeRollNo(student.rollNo),
    name: String(student.name ?? '').trim(),
    studentMobileNo: String(student.studentMobileNo ?? '').trim(),
    branch: String(student.branch ?? '').trim().toUpperCase(),
    yearOfStudy: normalizeYear(student.yearOfStudy ?? ''),
    section: String(student.section ?? '').trim().toUpperCase(),
    gender: String(student.gender ?? '').trim().toUpperCase(),
    hostellerDayScholar: String(student.hostellerDayScholar ?? '').trim().toUpperCase(),
    parentMobileNo: String(student.parentMobileNo ?? '').trim(),
    updatedAt: student.updatedAt ?? Date.now(),
    updatedBy: String(student.updatedBy ?? auth.currentUser?.email ?? 'unknown'),
  };
}

function didStudentChange(before, after) {
  if (!before) return true;
  const keys = [
    'rollNo',
    'name',
    'studentMobileNo',
    'branch',
    'yearOfStudy',
    'section',
    'gender',
    'hostellerDayScholar',
    'parentMobileNo',
  ];

  return keys.some((key) => String(before[key] ?? '') !== String(after[key] ?? ''));
}

function makeAuditEntry({ action, rollNo, before, after, sourceRoll, sourcePath }) {
  return {
    action,
    rollNo,
    actorUid: auth.currentUser?.uid ?? 'unknown',
    actorEmail: auth.currentUser?.email ?? 'unknown',
    timestamp: Date.now(),
    before: before ?? null,
    after: after ?? null,
    sourceRoll: sourceRoll ?? null,
    sourcePath: sourcePath ?? 'admin_portal',
  };
}

function LoginPane({ onLogin, loading, error }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  return (
    <div className="login-wrap">
      <div className="login-card">
        <h1>Admin Portal</h1>
        <p>Sign in to manage students with spreadsheet-style editing.</p>
        <label>Email</label>
        <input value={email} onChange={(e) => setEmail(e.target.value)} type="email" />
        <label>Password</label>
        <input value={password} onChange={(e) => setPassword(e.target.value)} type="password" />
        {error ? <div className="error-inline">{error}</div> : null}
        <button
          className="btn primary"
          disabled={loading}
          onClick={() => onLogin(email, password)}
        >
          {loading ? 'Signing in...' : 'Sign in'}
        </button>
      </div>
    </div>
  );
}

function App() {
  const [user, setUser] = useState(null);
  const [isAdmin, setIsAdmin] = useState(false);
  const [authLoading, setAuthLoading] = useState(true);
  const [loginLoading, setLoginLoading] = useState(false);
  const [loginError, setLoginError] = useState('');
  const [activeCollege, setActiveCollege] = useState('kec');
  const collegeId = activeCollege;

  const [hierarchy, setHierarchy] = useState({});
  const [selected, setSelected] = useState({ branch: '', yearOfStudy: '', section: '' });

  const [rows, setRows] = useState([]);
  const [originalRowsByRoll, setOriginalRowsByRoll] = useState({});
  const [deletedRolls, setDeletedRolls] = useState(new Set());
  const [undoStack, setUndoStack] = useState([]);
  const [redoStack, setRedoStack] = useState([]);
  const [searchRoll, setSearchRoll] = useState('');
  const [pasteData, setPasteData] = useState('');

  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

  const [meta, setMeta] = useState(null);
  const [versionHistory, setVersionHistory] = useState([]);
  const [showHistory, setShowHistory] = useState(false);
  const [rollbackVersion, setRollbackVersion] = useState('');

  const currentCollege = useMemo(
    () => COLLEGES.find((college) => college.id === activeCollege) ?? COLLEGES[0],
    [activeCollege],
  );

  function snapshotRows(sourceRows) {
    return sourceRows.map((row) => ({ ...row }));
  }

  function captureHistory() {
    setUndoStack((prev) => [
      ...prev.slice(-49),
      {
        rows: snapshotRows(rows),
        deletedRolls: Array.from(deletedRolls),
      },
    ]);
    setRedoStack([]);
  }

  function restoreSnapshot(snapshot) {
    setRows(snapshotRows(snapshot.rows));
    setDeletedRolls(new Set(snapshot.deletedRolls));
  }

  function undoChanges() {
    if (!undoStack.length) return;
    const previous = undoStack[undoStack.length - 1];
    setUndoStack((prev) => prev.slice(0, -1));
    setRedoStack((prev) => [
      ...prev,
      {
        rows: snapshotRows(rows),
        deletedRolls: Array.from(deletedRolls),
      },
    ]);
    restoreSnapshot(previous);
  }

  function redoChanges() {
    if (!redoStack.length) return;
    const next = redoStack[redoStack.length - 1];
    setRedoStack((prev) => prev.slice(0, -1));
    setUndoStack((prev) => [
      ...prev,
      {
        rows: snapshotRows(rows),
        deletedRolls: Array.from(deletedRolls),
      },
    ]);
    restoreSnapshot(next);
  }

  function focusGridCell(rowIndex, colIndex) {
    const target = document.querySelector(`[data-cell=\"${rowIndex}-${colIndex}\"]`);
    if (!target) return;
    target.focus();
    if (target.tagName === 'INPUT') {
      target.select();
    }
  }

  function handleGridKeyDown(event, rowIndex, colIndex) {
    const key = event.key;
    let nextRow = rowIndex;
    let nextCol = colIndex;

    if (key === 'ArrowRight') nextCol += 1;
    else if (key === 'ArrowLeft') nextCol -= 1;
    else if (key === 'ArrowDown') nextRow += 1;
    else if (key === 'ArrowUp') nextRow -= 1;
    else if (key === 'Enter') nextRow += event.shiftKey ? -1 : 1;
    else if (key === 'Tab') {
      if (event.shiftKey) {
        nextCol -= 1;
      } else {
        nextCol += 1;
      }
    } else {
      return;
    }

    event.preventDefault();

    if (nextCol < 0) {
      nextRow -= 1;
      nextCol = COLUMN_CONFIG.length - 1;
    }

    if (nextCol >= COLUMN_CONFIG.length) {
      nextRow += 1;
      nextCol = 0;
    }

    if (nextRow < 0) nextRow = 0;
    if (nextRow >= filteredRows.length) nextRow = filteredRows.length - 1;

    focusGridCell(nextRow, nextCol);
  }

  function isCellDirty(row, key) {
    const source = originalRowsByRoll[row._sourceRoll] || originalRowsByRoll[row.rollNo];
    if (!source) {
      return String(row[key] ?? '').trim() !== '';
    }
    return String(row[key] ?? '').trim() !== String(source[key] ?? '').trim();
  }

  function isRowDirty(row) {
    if (!row) return false;
    return COLUMN_CONFIG.some((col) => isCellDirty(row, col.key));
  }

  useEffect(() => {
    return onAuthStateChanged(auth, async (nextUser) => {
      setUser(nextUser);
      if (!nextUser) {
        setIsAdmin(false);
        setAuthLoading(false);
        return;
      }

      const tokenResult = await nextUser.getIdTokenResult(true);
      setIsAdmin(Boolean(tokenResult.claims.admin));
      setAuthLoading(false);
    });
  }, []);

  useEffect(() => {
    if (!isAdmin) return;
    loadHierarchy();
    const metaRef = ref(db, `colleges/${collegeId}/meta`);
    const off = onValue(metaRef, (snap) => {
      setMeta(snap.exists() ? snap.val() : null);
    });

    const versionsRef = ref(db, `colleges/${collegeId}/versions`);
    const offVersions = onValue(versionsRef, (snap) => {
      if (!snap.exists()) {
        setVersionHistory([]);
        return;
      }
      const raw = snap.val() || {};
      const entries = Object.entries(raw)
        .map(([version, value]) => ({ version, metadata: value.metadata || {} }))
        .sort((a, b) => compareVersionsDescending(a.version, b.version));
      setVersionHistory(entries);
    });

    return () => {
      off();
      offVersions();
    };
  }, [isAdmin, collegeId]);

  useEffect(() => {
    setSelected({ branch: '', yearOfStudy: '', section: '' });
    setRows([]);
    setOriginalRowsByRoll({});
    setDeletedRolls(new Set());
    setUndoStack([]);
    setRedoStack([]);
    setSearchRoll('');
    setPasteData('');
    setMessage('');
    setError('');
  }, [activeCollege]);

  useEffect(() => {
    const onKeyDown = (event) => {
      const isUndo = (event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'z' && !event.shiftKey;
      const isRedo =
        (event.ctrlKey || event.metaKey) &&
        (event.key.toLowerCase() === 'y' || (event.key.toLowerCase() === 'z' && event.shiftKey));

      if (isUndo) {
        event.preventDefault();
        undoChanges();
      }

      if (isRedo) {
        event.preventDefault();
        redoChanges();
      }
    };

    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [undoStack, redoStack, rows, deletedRolls]);

  async function loadHierarchy() {
    const snap = await get(ref(db, `colleges/${collegeId}/hierarchy`));
    setHierarchy(snap.exists() ? snap.val() : {});
  }

  async function loadSectionStudents(branch, yearOfStudy, section) {
    setBusy(true);
    setError('');
    setMessage('');

    try {
      const sectionPath = `colleges/${collegeId}/hierarchy/${branch}/${yearOfStudy}/${section}`;
      const sectionSnap = await get(ref(db, sectionPath));
      const rollNos = sectionSnap.exists() ? Object.keys(sectionSnap.val()) : [];

      if (rollNos.length === 0) {
        setRows([]);
        setOriginalRowsByRoll({});
        setDeletedRolls(new Set());
        setUndoStack([]);
        setRedoStack([]);
        setBusy(false);
        return;
      }

      const studentReads = await Promise.all(
        rollNos.map(async (roll) => {
          const studentSnap = await get(ref(db, `colleges/${collegeId}/studentsByRoll/${roll}`));
          if (!studentSnap.exists()) {
            return normalizeStudent({ rollNo: roll }, { branch, yearOfStudy, section });
          }
          return normalizeStudent(studentSnap.val(), { branch, yearOfStudy, section });
        }),
      );

      studentReads.sort((a, b) => a.rollNo.localeCompare(b.rollNo));
      setRows(studentReads);
      setOriginalRowsByRoll(
        Object.fromEntries(studentReads.map((r) => [r.rollNo, { ...r, _sourceRoll: r.rollNo }])),
      );
      setDeletedRolls(new Set());
      setUndoStack([]);
      setRedoStack([]);
      setSelected({ branch, yearOfStudy, section });
      setMessage(`Loaded ${studentReads.length} records.`);
    } catch (loadErr) {
      setError(loadErr.message || 'Failed to load section records.');
    } finally {
      setBusy(false);
    }
  }

  const filteredRows = useMemo(() => {
    const target = sanitizeRollNo(searchRoll);
    if (!target) return rows;
    return rows.filter((row) => row.rollNo.includes(target));
  }, [rows, searchRoll]);

  async function handleLogin(email, password) {
    setLoginLoading(true);
    setLoginError('');
    try {
      await signInWithEmailAndPassword(auth, email.trim(), password);
    } catch (loginErr) {
      setLoginError(loginErr.message || 'Sign in failed');
    } finally {
      setLoginLoading(false);
    }
  }

  function updateCell(rollNo, key, value) {
    captureHistory();
    setRows((prev) =>
      prev.map((row) => {
        if (row.rollNo !== rollNo) return row;

        if (key === 'rollNo') return { ...row, rollNo: sanitizeRollNo(value) };
        if (key === 'yearOfStudy') return { ...row, yearOfStudy: normalizeYear(value) };
        return { ...row, [key]: String(value).trimStart() };
      }),
    );
  }

  function addNewRow() {
    captureHistory();
    const placeholder = `NEW${Date.now()}`;
    setRows((prev) => [
      ...prev,
      normalizeStudent(
        {
          rollNo: placeholder,
          name: '',
          studentMobileNo: '',
          branch: selected.branch,
          yearOfStudy: selected.yearOfStudy,
          section: selected.section,
        },
        selected,
      ),
    ]);
  }

  function removeRow(rollNo) {
    captureHistory();
    setRows((prev) => prev.filter((row) => row.rollNo !== rollNo));
    if (originalRowsByRoll[rollNo]) {
      setDeletedRolls((prev) => {
        const next = new Set(prev);
        next.add(rollNo);
        return next;
      });
    }
  }

  function importFromPaste() {
    const lines = pasteData
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter(Boolean);
    if (!lines.length) return;

    const parsed = lines.map((line) => {
      const cols = line.split(/\t|,/);
      return {
        rollNo: cols[0] ?? '',
        name: cols[1] ?? '',
        studentMobileNo: cols[2] ?? '',
        branch: cols[3] ?? selected.branch,
        yearOfStudy: cols[4] ?? selected.yearOfStudy,
        section: cols[5] ?? selected.section,
        gender: cols[6] ?? '',
        hostellerDayScholar: cols[7] ?? '',
        parentMobileNo: cols[8] ?? '',
      };
    });

    const rowsFromPaste = parseRowsFromJson(parsed, selected);
    captureHistory();
    mergeRows(rowsFromPaste);
    setPasteData('');
  }

  async function importFromExcel(file) {
    if (!file) return;
    const bytes = await file.arrayBuffer();
    const workbook = XLSX.read(bytes, { type: 'array' });
    const firstSheet = workbook.Sheets[workbook.SheetNames[0]];
    const jsonRows = XLSX.utils.sheet_to_json(firstSheet, { defval: '' });
    const parsedRows = parseRowsFromJson(jsonRows, selected);
    captureHistory();
    mergeRows(parsedRows);
  }

  function mergeRows(nextRows) {
    setRows((prev) => {
      const byRoll = Object.fromEntries(prev.map((row) => [row.rollNo, row]));
      for (const row of nextRows) {
        byRoll[row.rollNo] = row;
      }
      return Object.values(byRoll).sort((a, b) => a.rollNo.localeCompare(b.rollNo));
    });
  }

  async function saveAll() {
    setBusy(true);
    setError('');
    setMessage('');

    try {
      const updates = {};
      const now = Date.now();
      const loadedPath = selected;
      let auditCounter = 0;

      const pushAudit = (entry) => {
        auditCounter += 1;
        const auditId = `${now}_${auditCounter}_${entry.action}_${entry.rollNo}`;
        updates[`colleges/${collegeId}/audit/studentMutations/${auditId}`] = entry;
      };

      for (const oldRoll of deletedRolls) {
        const old = originalRowsByRoll[oldRoll];
        if (!old) continue;
        const before = toPersistedStudentShape(old);
        updates[`colleges/${collegeId}/studentsByRoll/${oldRoll}`] = null;
        updates[`colleges/${collegeId}/hierarchy/${old.branch}/${old.yearOfStudy}/${old.section}/${oldRoll}`] = null;
        pushAudit(
          makeAuditEntry({
            action: 'delete',
            rollNo: oldRoll,
            before,
            after: null,
            sourceRoll: oldRoll,
          }),
        );
      }

      for (const row of rows) {
        const normalized = normalizeStudent(row, loadedPath);
        const rollNo = sanitizeRollNo(normalized.rollNo);
        const sourceRoll = sanitizeRollNo(row._sourceRoll || rollNo);
        if (!rollNo || rollNo.startsWith('NEW')) {
          continue;
        }

        const missingCore = !normalized.name || !normalized.studentMobileNo || !normalized.branch;
        if (missingCore) {
          throw new Error(`Missing core fields for ${rollNo}. Required: name, studentMobileNo, branch.`);
        }

        normalized.rollNo = rollNo;
        normalized.updatedAt = now;
        normalized.updatedBy = auth.currentUser?.email ?? 'unknown';
        const persistedNormalized = toPersistedStudentShape(normalized);

        const original = originalRowsByRoll[sourceRoll] || originalRowsByRoll[rollNo];
        const persistedOriginal = original ? toPersistedStudentShape(original) : null;
        if (sourceRoll && sourceRoll !== rollNo && original) {
          updates[`colleges/${collegeId}/studentsByRoll/${sourceRoll}`] = null;
          updates[
            `colleges/${collegeId}/hierarchy/${original.branch}/${original.yearOfStudy}/${original.section}/${sourceRoll}`
          ] = null;
        }
        if (
          original &&
          (original.branch !== normalized.branch ||
            original.yearOfStudy !== normalized.yearOfStudy ||
            original.section !== normalized.section)
        ) {
          updates[
            `colleges/${collegeId}/hierarchy/${original.branch}/${original.yearOfStudy}/${original.section}/${original.rollNo}`
          ] = null;
        }

        updates[`colleges/${collegeId}/studentsByRoll/${rollNo}`] = {
          rollNo: persistedNormalized.rollNo,
          name: persistedNormalized.name,
          studentMobileNo: persistedNormalized.studentMobileNo,
          branch: persistedNormalized.branch,
          yearOfStudy: persistedNormalized.yearOfStudy,
          section: persistedNormalized.section,
          gender: persistedNormalized.gender,
          hostellerDayScholar: persistedNormalized.hostellerDayScholar,
          parentMobileNo: persistedNormalized.parentMobileNo,
          updatedAt: persistedNormalized.updatedAt,
          updatedBy: persistedNormalized.updatedBy,
        };
        updates[
          `colleges/${collegeId}/hierarchy/${normalized.branch}/${normalized.yearOfStudy}/${normalized.section}/${rollNo}`
        ] = true;

        const changed = didStudentChange(persistedOriginal, persistedNormalized);
        if (changed) {
          const action = persistedOriginal ? 'update' : 'create';
          pushAudit(
            makeAuditEntry({
              action,
              rollNo,
              before: persistedOriginal,
              after: persistedNormalized,
              sourceRoll,
            }),
          );
        }
      }

      const metaRef = ref(db, `colleges/${collegeId}/meta/currentVersion`);
      const txResult = await runTransaction(metaRef, (current) => {
        const currentStr = typeof current === 'string' ? current : (current || '1.0');
        const [majorStr, patchStr] = currentStr.split('.');
        const major = Number.parseInt(majorStr || '1', 10) || 1;
        const patch = Number.parseInt(patchStr || '0', 10) || 0;
        const nextPatch = patch + 1;
        return `${major}.${nextPatch}`;
      });

      if (!txResult.committed || !txResult.snapshot.exists()) {
        throw new Error('Version bump transaction failed. No data was written.');
      }

      const nextVersion = txResult.snapshot.val();
      const recordCount = rows.filter((r) => !String(r.rollNo || '').startsWith('NEW')).length;

      updates[`colleges/${collegeId}/meta/currentVersion`] = nextVersion;
      updates[`colleges/${collegeId}/meta/updatedAt`] = now;
      updates[`colleges/${collegeId}/meta/updatedBy`] = auth.currentUser?.email ?? 'unknown';
      updates[`colleges/${collegeId}/versions/${versionToKey(nextVersion)}/studentsByRoll`] =
        rows
          .filter((r) => !String(r.rollNo || '').startsWith('NEW'))
          .reduce((acc, r) => {
            const persisted = toPersistedStudentShape(r);
            acc[persisted.rollNo] = persisted;
            return acc;
          }, {});
      updates[`colleges/${collegeId}/versions/${versionToKey(nextVersion)}/metadata`] = {
        version: nextVersion,
        timestamp: now,
        updatedBy: auth.currentUser?.email ?? 'unknown',
        changeSummary: `Bulk save from admin portal (${recordCount} records)`,
        recordCount,
      };

      await update(ref(db), updates);
      await loadHierarchy();

      if (selected.branch && selected.yearOfStudy && selected.section) {
        await loadSectionStudents(selected.branch, selected.yearOfStudy, selected.section);
      }

      setMessage('Saved to database successfully.');
      setOriginalRowsByRoll(
        Object.fromEntries(
          rows
            .map((r) => normalizeStudent(r, selected))
            .filter((r) => r.rollNo && !r.rollNo.startsWith('NEW'))
            .map((r) => [r.rollNo, { ...r, _sourceRoll: r.rollNo }]),
        ),
      );
      setDeletedRolls(new Set());
      setUndoStack([]);
      setRedoStack([]);
    } catch (saveErr) {
      setError(saveErr.message || 'Failed to save changes.');
    } finally {
      setBusy(false);
    }
  }

  const dirtyRowsCount = useMemo(() => {
    const dirtyRows = rows.filter((row) => isRowDirty(row)).length;
    return dirtyRows + deletedRolls.size;
  }, [rows, deletedRolls, originalRowsByRoll]);

  if (authLoading) {
    return <div className="splash">Loading portal...</div>;
  }

  if (!user) {
    return <LoginPane onLogin={handleLogin} loading={loginLoading} error={loginError} />;
  }

  if (!isAdmin) {
    return (
      <div className="splash">
        <div className="not-admin-card">
          <h2>Access restricted</h2>
          <p>This account does not have admin claim access.</p>
          <button className="btn" onClick={() => signOut(auth)}>
            Sign out
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="page" style={{ minHeight: '100vh', backgroundColor: '#F5F7FA' }}>
      <aside
        style={{
          position: 'fixed',
          top: 0,
          left: 0,
          bottom: 0,
          width: 220,
          backgroundColor: '#1565C0',
          color: '#FFFFFF',
          padding: '24px 14px',
          overflowY: 'auto',
        }}
      >
        <div style={{ fontSize: 20, fontWeight: 700, marginBottom: 20 }}>QR Scanner Admin</div>
        <div style={{ display: 'grid', gap: 10 }}>
          {COLLEGES.map((college) => {
            const active = activeCollege === college.id;
            return (
              <button
                key={college.id}
                type="button"
                onClick={() => setActiveCollege(college.id)}
                style={{
                  textAlign: 'left',
                  border: 'none',
                  borderRadius: 10,
                  padding: '10px 12px',
                  cursor: 'pointer',
                  backgroundColor: active ? '#FFFFFF' : 'transparent',
                  color: active ? '#1565C0' : '#FFFFFF',
                  fontWeight: active ? 700 : 500,
                }}
              >
                <div>{`🎓 ${college.name}`}</div>
                <div style={{ fontSize: 12, opacity: active ? 0.85 : 0.9 }}>{`[${college.id}]`}</div>
              </button>
            );
          })}
        </div>
      </aside>

      <div style={{ marginLeft: 220, minHeight: '100vh', padding: 32 }}>
        <header className="topbar">
          <div>
            <h1>{`${currentCollege.name} — Student Data Management`}</h1>
            <p>
              <span className="version-pill">
                {`v${meta?.currentVersion ?? '1.0'} · ${meta?.recordCount ?? rows.length} students`}
              </span>
            </p>
          </div>
          <div className="topbar-actions">
            <input
              className="search-box"
              placeholder="Search roll no"
              value={searchRoll}
              onChange={(e) => setSearchRoll(e.target.value)}
            />
            <button className="btn" type="button" onClick={() => setShowHistory(true)}>
              Version history
            </button>
            <button className="btn" onClick={() => signOut(auth)}>Sign out</button>
          </div>
        </header>

        <main className="layout">
        <aside className="sidebar">
          <h3>Department Hierarchy</h3>
          {Object.keys(hierarchy).length === 0 ? <p className="muted">No hierarchy data yet.</p> : null}
          {Object.entries(hierarchy).map(([branch, years]) => (
            <div className="tree-branch" key={branch}>
              <div className="tree-title">{branch}</div>
              {Object.entries(years).map(([year, sections]) => (
                <div key={`${branch}-${year}`} className="tree-year">
                  <div className="tree-subtitle">Year {year}</div>
                  <div className="tree-sections">
                    {Object.keys(sections).map((section) => {
                      const active =
                        selected.branch === branch &&
                        selected.yearOfStudy === year &&
                        selected.section === section;
                      return (
                        <button
                          key={`${branch}-${year}-${section}`}
                          className={`section-chip ${active ? 'active' : ''}`}
                          onClick={() => loadSectionStudents(branch, year, section)}
                        >
                          {section}
                        </button>
                      );
                    })}
                  </div>
                </div>
              ))}
            </div>
          ))}
        </aside>

        <section className="content">
          <div className="content-header">
            <div className="path-pill">
              {selected.branch ? `${selected.branch} / ${selected.yearOfStudy} / ${selected.section}` : 'Select a section'}
            </div>
            <div className="content-actions">
              <button className="btn" disabled={!undoStack.length} onClick={undoChanges}>Undo</button>
              <button className="btn" disabled={!redoStack.length} onClick={redoChanges}>Redo</button>
              <label className="btn file-btn">
                Import Excel
                <input
                  type="file"
                  accept=".xlsx,.xls,.csv"
                  onChange={(e) => importFromExcel(e.target.files?.[0])}
                />
              </label>
              <button className="btn" onClick={addNewRow}>Add Row</button>
              <button className="btn primary" disabled={busy} onClick={saveAll}>
                {busy ? 'Saving...' : `Save All${dirtyRowsCount ? ` (${dirtyRowsCount} changes)` : ''}`}
              </button>
            </div>
          </div>

          {dirtyRowsCount ? (
            <div className="dirty-inline">Unsaved changes: {dirtyRowsCount}. Use Save All to sync to database.</div>
          ) : null}

          <div className="bulk-paste">
            <textarea
              value={pasteData}
              onChange={(e) => setPasteData(e.target.value)}
              placeholder="Bulk paste rows here (tab or comma separated): rollNo, name, studentMobileNo, branch, year, section, gender, hostellerDayScholar, parentMobileNo"
            />
            <button className="btn" onClick={importFromPaste}>Import Pasted Rows</button>
          </div>

          {message ? <div className="success-inline">{message}</div> : null}
          {error ? <div className="error-inline">{error}</div> : null}

          <div className="grid-wrap">
            <table className="sheet-table">
              <thead>
                <tr>
                  <th>Actions</th>
                  {COLUMN_CONFIG.map((col) => (
                    <th key={col.key}>{col.label}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {filteredRows.map((row, rowIndex) => (
                  <tr key={row.rollNo} className={isRowDirty(row) ? 'row-dirty' : ''}>
                    <td>
                      <button className="link-btn" onClick={() => removeRow(row.rollNo)}>Delete</button>
                    </td>
                    {COLUMN_CONFIG.map((col, colIndex) => (
                      <td key={`${row.rollNo}-${col.key}`} className={isCellDirty(row, col.key) ? 'dirty-cell' : ''}>
                        {col.key === 'yearOfStudy' ? (
                          <select
                            value={row[col.key] ?? ''}
                            onChange={(e) => updateCell(row.rollNo, col.key, e.target.value)}
                            onKeyDown={(e) => handleGridKeyDown(e, rowIndex, colIndex)}
                            data-cell={`${rowIndex}-${colIndex}`}
                          >
                            <option value="">Select</option>
                            {YEAR_OPTIONS.map((y) => (
                              <option key={y} value={y}>{y}</option>
                            ))}
                          </select>
                        ) : col.key === 'gender' ? (
                          <select
                            value={row[col.key] ?? ''}
                            onChange={(e) => updateCell(row.rollNo, col.key, e.target.value)}
                            onKeyDown={(e) => handleGridKeyDown(e, rowIndex, colIndex)}
                            data-cell={`${rowIndex}-${colIndex}`}
                          >
                            {GENDER_OPTIONS.map((g) => (
                              <option key={g || 'none'} value={g}>{g || 'Select'}</option>
                            ))}
                          </select>
                        ) : col.key === 'hostellerDayScholar' ? (
                          <select
                            value={row[col.key] ?? ''}
                            onChange={(e) => updateCell(row.rollNo, col.key, e.target.value)}
                            onKeyDown={(e) => handleGridKeyDown(e, rowIndex, colIndex)}
                            data-cell={`${rowIndex}-${colIndex}`}
                          >
                            {RESIDENCE_OPTIONS.map((r) => (
                              <option key={r || 'none'} value={r}>{r || 'Select'}</option>
                            ))}
                          </select>
                        ) : (
                          <input
                            value={row[col.key] ?? ''}
                            onChange={(e) => updateCell(row.rollNo, col.key, e.target.value)}
                            onKeyDown={(e) => handleGridKeyDown(e, rowIndex, colIndex)}
                            data-cell={`${rowIndex}-${colIndex}`}
                          />
                        )}
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      </main>
      </div>

      {showHistory && (
        <div className="version-drawer">
          <div className="version-drawer-inner">
            <div className="version-drawer-header">
              <h2>Version history</h2>
              <button className="btn" type="button" onClick={() => setShowHistory(false)}>
                Close
              </button>
            </div>
            <table className="version-table">
              <thead>
                <tr>
                  <th>Version</th>
                  <th>Timestamp</th>
                  <th>Updated By</th>
                  <th>Summary</th>
                  <th>Records</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {versionHistory.map(({ version, metadata }) => (
                  <tr key={version}>
                    <td>{version}</td>
                    <td>{metadata.timestamp ? new Date(metadata.timestamp).toLocaleString() : '-'}</td>
                    <td>{metadata.updatedBy || 'unknown'}</td>
                    <td>{metadata.changeSummary || '-'}</td>
                    <td>{metadata.recordCount ?? '-'}</td>
                    <td>
                      <button
                        type="button"
                        className="btn link-btn"
                        disabled={rollbackVersion === version}
                        onClick={async () => {
                          if (rollbackVersion) return;
                          if (!window.confirm(`Rollback to version ${version}?`)) return;
                          try {
                            setRollbackVersion(version);
                            const snap = await get(
                              ref(db, `colleges/${collegeId}/versions/${versionToKey(version)}/studentsByRoll`),
                            );
                            const students = snap.exists() ? snap.val() : {};
                            const updates = {};
                            updates[`colleges/${collegeId}/studentsByRoll`] = students;

                            const nowTs = Date.now();
                            updates[`colleges/${collegeId}/meta/currentVersion`] = version;
                            updates[`colleges/${collegeId}/meta/updatedAt`] = nowTs;
                            updates[`colleges/${collegeId}/meta/updatedBy`] =
                              auth.currentUser?.email ?? 'unknown';
                            updates[`colleges/${collegeId}/versions/${versionToKey(version)}/metadata`] = {
                              ...(metadata || {}),
                              version,
                              timestamp: nowTs,
                              updatedBy: auth.currentUser?.email ?? 'unknown',
                              changeSummary: `Rollback to v${version}`,
                              recordCount: students ? Object.keys(students).length : 0,
                            };

                            await update(ref(db), updates);
                            alert(`Rolled back to version ${version}.`);
                          } catch (rollbackErr) {
                            console.error(rollbackErr);
                            alert('Failed to rollback version.');
                          } finally {
                            setRollbackVersion('');
                          }
                        }}
                      >
                        {rollbackVersion === version ? 'Rolling back...' : 'Rollback'}
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;
