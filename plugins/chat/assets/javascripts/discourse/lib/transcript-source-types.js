import { i18n } from "discourse-i18n";

const DEFAULT_ICON = "comment";

const sourceTypes = new Map();

export function registerTranscriptSourceType(type, { icon, label }) {
  sourceTypes.set(type, { icon, label });
}

// sourceType comes from post markup, so unknown values fall back to the defaults
export function transcriptSourcePresentation(type) {
  const registered = sourceTypes.get(type);

  return {
    icon: registered?.icon ?? DEFAULT_ICON,
    label: i18n(registered?.label ?? "chat.quote.transcript_label"),
  };
}

export function resetTranscriptSourceTypes() {
  sourceTypes.clear();
}
