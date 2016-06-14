import { withPluginApi } from 'discourse/lib/plugin-api';
import { registerEmoji } from 'pretty-text/emoji';

export default {
  name: 'enable-emoji',

  initialize(container) {
    const siteSettings = container.lookup('site-settings:main');
    if (!siteSettings.enable_emoji) { return; }

    withPluginApi('0.1', api => {
      api.onToolbarCreate(toolbar => {
        toolbar.addButton({
          id: 'emoji',
          group: 'extras',
          icon: 'smile-o',
          action: 'emoji',
          title: 'composer.emoji'
        });
      });
    });

    (PreloadStore.get("customEmoji") || []).forEach(emoji => registerEmoji(emoji.name, emoji.url));
  }
};
