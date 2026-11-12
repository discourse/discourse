import KeyValueStore from "discourse/lib/key-value-store";

const STORE_CONTEXT = "discourse_chat_alerts_";
const STORE_KEY = "handled";
const EXPIRY_MS = 5 * 60 * 1000;
const MAX_ENTRIES = 100;

const store = new KeyValueStore(STORE_CONTEXT);

// claims are read-then-written, so two tabs can both claim the same alert;
// tagging them keeps one tab's release from dropping the other's claim
const TAB_ID = Math.random().toString(36).slice(2);

function readEntries() {
  const now = Date.now();
  return (store.getObject(STORE_KEY) || []).filter(
    (entry) => now - entry.at < EXPIRY_MS
  );
}

function writeEntries(entries) {
  store.setObject({ key: STORE_KEY, value: entries.slice(-MAX_ENTRIES) });
}

// Tabs receive the same alert at different times, hidden tabs get the
// MessageBus backlog when they wake — so the first tab to handle an alert
// records it here to keep later tabs from replaying its sound.
export function claimChatAlert(key) {
  if (!key) {
    return true;
  }

  const entries = readEntries();

  if (entries.some((entry) => entry.key === key)) {
    return false;
  }

  entries.push({ key, at: Date.now(), tab: TAB_ID });
  writeEntries(entries);

  return true;
}

// for alerts this tab actually played: re-records the claim as this tab's in
// case another tab claimed it in the same instant and later releases it
export function confirmChatAlert(key) {
  if (!key) {
    return;
  }

  const entries = readEntries().filter((entry) => entry.key !== key);
  entries.push({ key, at: Date.now(), tab: TAB_ID, played: true });
  writeEntries(entries);
}

// a claim alone doesn't mean a sound played, a visible tab claims alerts for
// its open channel silently
export function chatAlertPlayed(key) {
  return readEntries().some((entry) => entry.key === key && entry.played);
}

// for claims that turned out to be unplayable in this tab (e.g. suspended
// audio context), so another tab can still play the sound
export function releaseChatAlert(key) {
  if (!key) {
    return;
  }

  writeEntries(
    readEntries().filter((entry) => entry.key !== key || entry.tab !== TAB_ID)
  );
}

export function resetChatAlerts() {
  store.abandonLocal();
}
