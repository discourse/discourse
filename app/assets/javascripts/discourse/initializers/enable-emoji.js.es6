import { showSelector } from "discourse/lib/emoji/emoji-toolbar";
import { onToolbarCreate } from 'discourse/components/d-editor';

export default {
  name: 'enable-emoji',

  initialize(container) {
    const siteSettings = container.lookup('site-settings:main');
    if (siteSettings.enable_emoji) {

      onToolbarCreate(toolbar => {
        toolbar.addButton({
          id: 'emoji',
          group: 'extras',
          icon: 'smile-o',
          action: 'emoji',
          shortcut: 'Alt+E',
          title: 'composer.emoji'
        });
      });

      window.PagedownCustom.appendButtons.push({
        id: 'wmd-emoji-button',
        description: I18n.t("composer.emoji"),
        execute() {
          showSelector({
            container,
            onSelect(title) {
              const composerController = container.lookup('controller:composer');
              composerController.appendTextAtCursor(`:${title}:`, {space: true});
            },
          });
        }
      });
    }
  }
};
