import Service, { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import discourseDebounce from "discourse-common/lib/debounce";
import { bind } from "discourse-common/utils/decorators";
import { mentionRegex } from "pretty-text/mentions";
import { cancel } from "@ember/runloop";
import { tracked } from "@glimmer/tracking";

const MENTION_RESULT = {
  invalid: -1,
  unreachable: 0,
  over_members_limit: 1,
};

const MENTION_DEBOUNCE_MS = 1000;

export default class ChatComposerWarningsTracker extends Service {
  @service siteSettings;

  // Track mention hints to display warnings
  @tracked unreachableGroupMentions = [];
  @tracked overMembersLimitGroupMentions = [];
  @tracked tooManyMentions = false;
  @tracked channelWideMentionDisallowed = false;
  @tracked mentionsCount = 0;
  @tracked mentionsTimer = null;

  // Complimentary structure to avoid repeating mention checks.
  _mentionWarningsSeen = {};

  willDestroy() {
    cancel(this.mentionsTimer);
  }

  @bind
  reset() {
    this.unreachableGroupMentions = [];
    this.unreachableGroupMentions = [];
    this.overMembersLimitGroupMentions = [];
    this.tooManyMentions = false;
    this.channelWideMentionDisallowed = false;
    this.mentionsCount = 0;
    cancel(this.mentionsTimer);
  }

  @bind
  trackMentions(currentMessage, skipDebounce) {
    if (skipDebounce) {
      return this._trackMentions(currentMessage);
    }

    this.mentionsTimer = discourseDebounce(
      this,
      this._trackMentions,
      currentMessage,
      MENTION_DEBOUNCE_MS
    );
  }

  @bind
  _trackMentions(currentMessage) {
    if (!this.siteSettings.enable_mentions) {
      return;
    }

    const mentions = this._extractMentions(currentMessage.message);
    this.mentionsCount = mentions?.length;

    if (this.mentionsCount > 0) {
      this.tooManyMentions =
        this.mentionsCount > this.siteSettings.max_mentions_per_chat_message;

      if (!this.tooManyMentions) {
        const newMentions = mentions.filter(
          (mention) => !(mention in this._mentionWarningsSeen)
        );

        this.channelWideMentionDisallowed =
          !currentMessage.channel.allowChannelWideMentions &&
          (mentions.includes("here") || mentions.includes("all"));

        if (newMentions?.length > 0) {
          this._recordNewWarnings(newMentions, mentions);
        } else {
          this._rebuildWarnings(mentions);
        }
      }
    } else {
      this.tooManyMentions = false;
      this.channelWideMentionDisallowed = false;
      this.unreachableGroupMentions = [];
      this.overMembersLimitGroupMentions = [];
    }
  }

  _extractMentions(message) {
    const regex = mentionRegex(this.siteSettings.unicode_usernames);
    const mentions = [];
    let mentionsLeft = true;

    while (mentionsLeft) {
      const matches = message.match(regex);

      if (matches) {
        const mention = matches[1] || matches[2];
        mentions.push(mention);
        message = message.replaceAll(`${mention}`, "");

        if (mentions.length > this.siteSettings.max_mentions_per_chat_message) {
          mentionsLeft = false;
        }
      } else {
        mentionsLeft = false;
      }
    }

    return mentions;
  }

  _recordNewWarnings(newMentions, mentions) {
    ajax("/chat/api/mentions/groups.json", {
      data: { mentions: newMentions },
    })
      .then((newWarnings) => {
        newWarnings.unreachable.forEach((warning) => {
          this._mentionWarningsSeen[warning] = MENTION_RESULT["unreachable"];
        });

        newWarnings.over_members_limit.forEach((warning) => {
          this._mentionWarningsSeen[warning] =
            MENTION_RESULT["over_members_limit"];
        });

        newWarnings.invalid.forEach((warning) => {
          this._mentionWarningsSeen[warning] = MENTION_RESULT["invalid"];
        });

        this._rebuildWarnings(mentions);
      })
      .catch(this._rebuildWarnings(mentions));
  }

  _rebuildWarnings(mentions) {
    const newWarnings = mentions.reduce(
      (memo, mention) => {
        if (
          mention in this._mentionWarningsSeen &&
          !(this._mentionWarningsSeen[mention] === MENTION_RESULT["invalid"])
        ) {
          if (
            this._mentionWarningsSeen[mention] === MENTION_RESULT["unreachable"]
          ) {
            memo[0].push(mention);
          } else {
            memo[1].push(mention);
          }
        }

        return memo;
      },
      [[], []]
    );

    this.unreachableGroupMentions = newWarnings[0];
    this.overMembersLimitGroupMentions = newWarnings[1];
  }
}
