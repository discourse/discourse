import { performEmojiUnescape } from "pretty-text/emoji";

const rule = {
  tag: "quote",

  before(state, tagInfo) {
    const attrs = tagInfo.attrs;
    let options = state.md.options.discourse;

    let quoteInfo = attrs["_default"];
    let username,
      postNumber,
      topicId,
      avatarImg,
      primaryGroupName,
      full,
      displayName;

    if (quoteInfo) {
      let split = quoteInfo.split(/\,\s*/);
      username = split[0];

      let i;
      for (i = 1; i < split.length; i++) {
        if (split[i].indexOf("post:") === 0) {
          postNumber = parseInt(split[i].substr(5), 10);
          continue;
        }

        if (split[i].indexOf("topic:") === 0) {
          topicId = parseInt(split[i].substr(6), 10);
          continue;
        }

        if (/full:\s*true/.test(split[i])) {
          full = true;
          continue;
        }
      }
    }

    if (options.lookupAvatarByPostNumber) {
      // client-side, we can retrieve the avatar from the post
      avatarImg = options.lookupAvatarByPostNumber(postNumber, topicId);
    } else if (options.lookupAvatar) {
      // server-side, we need to lookup the avatar from the username
      avatarImg = options.lookupAvatar(username);
    }

    if (options.lookupPrimaryUserGroupByPostNumber) {
      // client-side, we can retrieve the primary user group from the post
      primaryGroupName = options.lookupPrimaryUserGroupByPostNumber(
        postNumber,
        topicId
      );
    } else if (options.lookupPrimaryUserGroup) {
      // server-side, we need to lookup the primary user group from the username
      primaryGroupName = options.lookupPrimaryUserGroup(username);
    }

    if (options.formatUsername) {
      displayName = options.formatUsername(username);
    } else {
      displayName = username;
    }

    let token = state.push("bbcode_open", "aside", 1);
    token.attrs = [];

    if (primaryGroupName && primaryGroupName.length !== 0) {
      token.attrs.push(["class", `quote group-${primaryGroupName}`]);
    } else {
      token.attrs.push(["class", "quote no-group"]);
    }

    if (username) {
      token.attrs.push(["data-username", username]);
    }

    if (postNumber) {
      token.attrs.push(["data-post", postNumber]);
    }

    if (topicId) {
      token.attrs.push(["data-topic", topicId]);
    }

    if (full) {
      token.attrs.push(["data-full", "true"]);
    }

    if (username) {
      let offTopicQuote =
        options.topicId &&
        postNumber &&
        options.getTopicInfo &&
        topicId !== options.topicId;

      // on topic quote
      token = state.push("quote_header_open", "div", 1);
      token.attrs = [["class", "title"]];

      token = state.push("quote_controls_open", "div", 1);
      token.attrs = [["class", "quote-controls"]];

      state.push("quote_controls_close", "div", -1);

      if (avatarImg) {
        token = state.push("html_inline", "", 0);
        token.content = avatarImg;
      }

      if (offTopicQuote) {
        const topicInfo = options.getTopicInfo(topicId);
        if (topicInfo) {
          let href = topicInfo.href;
          if (postNumber > 0) {
            href += "/" + postNumber;
          }

          let title = topicInfo.title;

          if (options.enableEmoji) {
            title = performEmojiUnescape(topicInfo.title, {
              getURL: options.getURL,
              emojiSet: options.emojiSet,
              emojiCDNUrl: options.emojiCDNUrl,
              enableEmojiShortcuts: options.enableEmojiShortcuts,
              inlineEmoji: options.inlineEmoji,
              lazy: true,
            });
          }

          token = state.push("link_open", "a", 1);
          token.attrs = [["href", href]];
          token.block = false;

          token = state.push("html_inline", "", 0);
          token.content = title;

          token = state.push("link_close", "a", -1);
          token.block = false;
        }
      } else {
        token = state.push("text", "", 0);
        token.content = ` ${displayName}:`;
      }

      state.push("quote_header_close", "div", -1);
    }

    state.push("bbcode_open", "blockquote", 1);
  },

  after(state) {
    state.push("bbcode_close", "blockquote", -1);
    state.push("bbcode_close", "aside", -1);
  },
};

export function setup(helper) {
  helper.registerOptions((opts, siteSettings) => {
    opts.enableEmoji = siteSettings.enable_emoji;
    opts.emojiSet = siteSettings.emoji_set;
    opts.emojiCDNUrl = siteSettings.external_emoji_url;
    opts.enableEmojiShortcuts = siteSettings.enable_emoji_shortcuts;
    opts.inlineEmoji = siteSettings.enable_inline_emoji_translation;
  });

  helper.registerPlugin((md) => {
    md.block.bbcode.ruler.push("quotes", rule);
  });

  helper.allowList(["img[class=avatar]", "img[loading=lazy]"]);
  helper.allowList({
    custom(tag, name, value) {
      if (tag === "aside" && name === "class") {
        return (
          value === "quote no-group" || !!/^quote group\-(.+)$/.exec(value)
        );
      }
    },
  });
}
