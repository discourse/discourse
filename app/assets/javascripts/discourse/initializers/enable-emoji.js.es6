import { showSelector } from "discourse/lib/emoji/emoji-toolbar";

export default {
  name: 'enable-emoji',

  initialize(container) {
    const siteSettings = container.lookup('site-settings:main');
    if (siteSettings.enable_emoji) {
      window.PagedownCustom.appendButtons.push({
        id: 'wmd-emoji-button',
        description: I18n.t("composer.emoji"),
        execute: showSelector
      });
    }
  }
};
