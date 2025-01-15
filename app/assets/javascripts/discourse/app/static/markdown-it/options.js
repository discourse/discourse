import { getURLWithCDN } from "discourse/lib/get-url";
import { helperContext } from "discourse/lib/helpers";
import { formatUsername } from "discourse/lib/utilities";

export default function buildOptions(options) {
  let context = helperContext();

  return {
    getURL: getURLWithCDN,
    currentUser: context.currentUser,
    censoredRegexp: context.site.censored_regexp,
    customEmojiTranslation: context.site.custom_emoji_translation,
    emojiDenyList: context.site.denied_emojis,
    siteSettings: context.siteSettings,
    formatUsername,
    watchedWordsReplace: context.site.watched_words_replace,
    watchedWordsLink: context.site.watched_words_link,
    additionalOptions: context.site.markdown_additional_options,
    ...options,
  };
}
