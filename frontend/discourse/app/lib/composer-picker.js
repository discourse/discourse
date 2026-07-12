import EmojiPanel from "discourse/components/composer-picker/emoji-panel";
import GifPanel from "discourse/components/composer-picker/gif-panel";

const CORE_TABS = [
  {
    id: "emoji",
    icon: "far-face-smile",
    title: "composer_picker.tabs.emoji",
    component: EmojiPanel,
    priority: 100,
    enabled: ({ siteSettings }) => siteSettings.enable_emoji,
  },
  {
    id: "gifs",
    icon: "gif",
    title: "composer_picker.tabs.gifs",
    component: GifPanel,
    priority: 90,
    // composerEvents !== false: enabled everywhere a surface doesn't opt out
    // (chat/tests omit it) but excluded on non-composer d-editors.
    enabled: ({ siteSettings, composerEvents }) =>
      siteSettings.enable_gifs && composerEvents !== false,
  },
];

let customTabs = [];

export function registerComposerPickerTab(tab) {
  if (!tab.id) {
    throw new Error("Attempted to register a composer picker tab with no id.");
  }

  const alreadyRegistered = [...CORE_TABS, ...customTabs].some(
    (existing) => existing.id === tab.id
  );
  if (alreadyRegistered) {
    return;
  }

  customTabs.push(tab);
}

export function resetComposerPickerTabs() {
  customTabs = [];
}

export function composerPickerTabs(owner, context = {}) {
  const siteSettings = owner.lookup("service:site-settings");

  return [...CORE_TABS, ...customTabs]
    .filter((tab) =>
      tab.enabled ? tab.enabled({ siteSettings, owner, ...context }) : true
    )
    .sort((a, b) => (b.priority ?? 0) - (a.priority ?? 0));
}
