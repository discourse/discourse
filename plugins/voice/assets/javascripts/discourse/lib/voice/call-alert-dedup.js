import KeyValueStore from "discourse/lib/key-value-store";

const STORE_CONTEXT = "discourse_voice_call_alerts_";
const STORE_KEY = "handled";
const EXPIRY_MS = 5 * 60 * 1000;
const MAX_ENTRIES = 50;

const store = new KeyValueStore(STORE_CONTEXT);

function readEntries() {
  const now = Date.now();
  return (store.getObject(STORE_KEY) || []).filter(
    (entry) => now - entry.at < EXPIRY_MS
  );
}

function writeEntries(entries) {
  store.setObject({ key: STORE_KEY, value: entries.slice(-MAX_ENTRIES) });
}

// Every open tab receives the same ring event (hidden tabs get it from the
// MessageBus backlog when they wake) — the first tab to handle it records it
// here so the others don't also ring and stack answer modals.
export function claimCallAlert(key) {
  if (!key) {
    return true;
  }

  const entries = readEntries();

  if (entries.some((entry) => entry.key === key)) {
    return false;
  }

  entries.push({ key, at: Date.now() });
  writeEntries(entries);

  return true;
}

// For claims that turned out unusable in this tab, so another tab can still
// take the ring.
export function releaseCallAlert(key) {
  if (!key) {
    return;
  }

  writeEntries(readEntries().filter((entry) => entry.key !== key));
}
