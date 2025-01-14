import { tracked } from "@glimmer/tracking";
import { cancel } from "@ember/runloop";
import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";

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
    this.#resetMentionStats();
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

    currentMessage.parseMentions().then((mentions) => {
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
            this.#recordNewWarnings(newMentions, mentions);
          } else {
            this.#rebuildWarnings(mentions);
          }
        }
      } else {
        this.#resetMentionStats();
      }
    });
  }

  #resetMentionStats() {
    this.tooManyMentions = false;
    this.channelWideMentionDisallowed = false;
    this.unreachableGroupMentions = [];
    this.overMembersLimitGroupMentions = [];
  }

  #recordNewWarnings(newMentions, mentions) {
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

        this.#rebuildWarnings(mentions);
      })
      .catch(this.#rebuildWarnings(mentions));
  }

  #rebuildWarnings(mentions) {
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
