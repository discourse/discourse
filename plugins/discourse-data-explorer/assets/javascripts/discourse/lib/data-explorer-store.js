import KeyValueStore from "discourse/lib/key-value-store";

export const dataExplorerStore = new KeyValueStore("discourse_data_explorer_");

const DEFAULT_MODE_KEY = "default_mode";

export function rememberedMode() {
  const stored = dataExplorerStore.get(DEFAULT_MODE_KEY);
  return stored === "ai" || stored === "manual" ? stored : null;
}

export function rememberMode(value) {
  dataExplorerStore.set({ key: DEFAULT_MODE_KEY, value });
}
