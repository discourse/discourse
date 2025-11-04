import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { cancel, later, schedule } from "@ember/runloop";
import A11ySkipLinks from "discourse/components/a11y/skip-links";
import discourseDebounce from "discourse/lib/debounce";
import { i18n } from "discourse-i18n";
import { forceFocus } from "../lib/dom-utils";

class TopicSkipLinks extends Component {
  #mutationObserver;
  #pendingFocusAttempt;

  willDestroy() {
    super.willDestroy(...arguments);
    this.#cleanupObserver();
  }

  get showTopicSkipLinks() {
    return this.args.topic?.last_read_post_number > 0;
  }

  get resumePostNumber() {
    if (this.args.topic.last_read_post_number > 1) {
      return this.args.topic.last_read_post_number;
    }

    return null;
  }

  get lastPostNumber() {
    return (
      this.args.topic.highest_post_number || this.args.topic.posts_count || null
    );
  }

  get resumeIsLastReply() {
    const resumePostNumber = this.args.topic.last_read_post_number;
    const lastPostNumber =
      this.args.topic.highest_post_number || this.args.topic.posts_count;

    return (
      resumePostNumber && lastPostNumber && resumePostNumber >= lastPostNumber
    );
  }

  get topicHasMultiplePosts() {
    const postsCount = this.args.topic.posts_count;
    return postsCount && postsCount > 1;
  }

  @action
  async focusSelector(selector, timeout = 3000) {
    this.#cleanupObserver();

    if (!selector) {
      return;
    }

    if (this.#tryFocusSelector(selector)) {
      return;
    }

    try {
      await this.#waitForSelectorWithTimeout(selector, timeout);
      this.#tryFocusSelector(selector);
    } finally {
      this.#cleanupObserver();
    }
  }

  #tryFocusSelector(selector) {
    const element = document.querySelector(selector);
    if (element) {
      forceFocus(element);
      return true;
    }
    return false;
  }

  #waitForSelectorWithTimeout(selector, timeout) {
    return new Promise((resolve) => {
      let timeoutTimer;

      const cleanupAndResolve = () => {
        if (timeoutTimer) {
          cancel(timeoutTimer);
        }
        this.#mutationObserver?.disconnect();
        resolve();
      };

      timeoutTimer = later(cleanupAndResolve, timeout);

      this.#mutationObserver = new MutationObserver(() => {
        this.#pendingFocusAttempt = discourseDebounce(
          this,
          () => {
            if (document.querySelector(selector)) {
              cleanupAndResolve();
            }
          },
          200
        );
      });

      this.#mutationObserver.observe(document, {
        childList: true,
        subtree: true,
        attributes: true,
      });
    });
  }

  #cleanupObserver() {
    this.#mutationObserver?.disconnect();
    this.#mutationObserver = null;

    if (this.#pendingFocusAttempt) {
      cancel(this.#pendingFocusAttempt);
    }
  }

  <template>
    <A11ySkipLinks>
      {{#if this.showTopicSkipLinks}}
        {{#if this.resumePostNumber}}
          {{#if this.resumeIsLastReply}}
            <SkipTo
              @topic={{@topic}}
              @postNumber={{this.resumePostNumber}}
              @onClick={{this.focusSelector}}
            >
              {{i18n
                "skip_to_where_you_left_off_last"
                post_number=this.resumePostNumber
              }}
            </SkipTo>
          {{else}}
            <SkipTo
              @topic={{@topic}}
              @postNumber={{this.resumePostNumber}}
              @onClick={{this.focusSelector}}
            >
              {{i18n
                "skip_to_where_you_left_off"
                post_number=this.resumePostNumber
              }}
            </SkipTo>
            {{#if this.topicHasMultiplePosts}}
              <SkipTo
                @topic={{@topic}}
                @postNumber={{this.lastPostNumber}}
                @onClick={{this.focusSelector}}
              >
                {{i18n "skip_to_last_reply"}}
              </SkipTo>
            {{/if}}
          {{/if}}
        {{else}}
          {{#if this.topicHasMultiplePosts}}
            <SkipTo
              @topic={{@topic}}
              @postNumber={{this.lastPostNumber}}
              @onClick={{this.focusSelector}}
            >
              {{i18n "skip_to_last_reply"}}
            </SkipTo>
          {{/if}}
        {{/if}}
        {{#if this.topicHasMultiplePosts}}
          <SkipTo
            @topic={{@topic}}
            @postNumber="1"
            @onClick={{this.focusSelector}}
          >
            {{i18n "skip_to_top"}}
          </SkipTo>
        {{/if}}
      {{/if}}
    </A11ySkipLinks>
  </template>
}

class SkipTo extends Component {
  get url() {
    return `${this.args.topic.url}/${this.args.postNumber}`;
  }

  @action
  async handleSkipToPost() {
    let focusSelector;

    if (Number(this.args.postNumber) === 1) {
      focusSelector = "#topic-title h1";
    } else {
      focusSelector = `[data-post-number="${this.args.postNumber}"] .post__body`;
    }

    schedule("afterRender", () => {
      this.args.onClick(focusSelector);
    });
  }

  <template>
    {{#if @postNumber}}
      <a href={{this.url}} {{on "click" this.handleSkipToPost}}>
        {{yield}}
      </a>
    {{/if}}
  </template>
}

export default TopicSkipLinks;
