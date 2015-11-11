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
          title: 'composer.emoji'
        });
      });

      // enable plugin emojis
      Discourse.Emoji.applyCustomEmojis();
    }
  }
};
