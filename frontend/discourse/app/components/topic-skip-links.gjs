import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { cancel, later, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import A11ySkipLinks from "discourse/components/a11y/skip-links";
import DiscourseURL from "discourse/lib/url";
import { i18n } from "discourse-i18n";
import { forceFocus } from "../lib/dom-utils";

class TopicSkipLinks extends Component {
  @service router;

  get showTopicSkipLinks() {
    return this.args.topic?.last_read_post_number > 0;
  }

  get resumePostNumber() {
    if (this.args.topic.last_read_post_number > 1) {
      return this.args.topic.last_read_post_number;
    }
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

  get currentPostNumber() {
    return (
      this.args.topic.currentPost ||
      parseInt(this.router.currentRoute?.params?.nearPost, 10) ||
      1
    );
  }

  get isDirectUrlToArbitraryPost() {
    const currentPost = this.currentPostNumber;
    const resumePost = this.args.topic.last_read_post_number;

    return currentPost > 1 && resumePost && currentPost !== resumePost;
  }

  <template>
    <A11ySkipLinks>
      {{#if this.showTopicSkipLinks}}
        {{#if this.isDirectUrlToArbitraryPost}}
          <SkipTo @topic={{@topic}} @postNumber={{this.currentPostNumber}}>
            {{i18n "skip_to_post" post_number=this.currentPostNumber}}
          </SkipTo>
        {{/if}}
        {{#if this.resumePostNumber}}
          {{#if this.resumeIsLastReply}}
            <SkipTo @topic={{@topic}} @postNumber={{this.resumePostNumber}}>
              {{i18n
                "skip_to_where_you_left_off_last"
                post_number=this.resumePostNumber
              }}
            </SkipTo>
          {{else}}
            <SkipTo @topic={{@topic}} @postNumber={{this.resumePostNumber}}>
              {{i18n
                "skip_to_where_you_left_off"
                post_number=this.resumePostNumber
              }}
            </SkipTo>
            {{#if this.topicHasMultiplePosts}}
              <SkipTo @topic={{@topic}} @postNumber={{this.lastPostNumber}}>
                {{i18n "skip_to_last_reply"}}
              </SkipTo>
            {{/if}}
          {{/if}}
        {{else}}
          {{#if this.topicHasMultiplePosts}}
            <SkipTo @topic={{@topic}} @postNumber={{this.lastPostNumber}}>
              {{i18n "skip_to_last_reply"}}
            </SkipTo>
          {{/if}}
        {{/if}}
        {{#if this.topicHasMultiplePosts}}
          <SkipTo @topic={{@topic}} @postNumber="1">
            {{i18n "skip_to_top"}}
          </SkipTo>
        {{/if}}
      {{/if}}
    </A11ySkipLinks>
  </template>
}

class SkipTo extends Component {
  #mutationObserver = null;

  willDestroy() {
    super.willDestroy();

    // clear any pending observer
    this.#mutationObserver?.disconnect();
  }

  get url() {
    return `${this.args.topic.url}/${this.args.postNumber}`;
  }

  @action
  async handleSkipToPost(evt) {
    evt.preventDefault();

    await DiscourseURL.routeTo(evt.target.href);

    let focusTarget;

    if (Number(this.args.postNumber) === 1) {
      focusTarget = document.querySelector("#topic-title h1");
    } else {
      focusTarget = document.querySelector(
        `[data-post-number="${this.args.postNumber}"] .post-username`
      );
    }

    schedule("afterRender", async () => {
      await this.#focusElement(focusTarget);
    });
  }

  async #focusElement(selector, timeout = 1000) {
    this.#mutationObserver?.disconnect();

    if (!selector) {
      return Promise.resolve(false);
    }

    const element = document.querySelector(selector);

    if (element) {
      forceFocus(element);
      return Promise.resolve(true);
    }

    try {
      return await new Promise((resolve) => {
        // if not fulfilled in time, resolve with false
        const timeoutTimer = later(() => {
          resolve(false);
        }, timeout);

        this.#mutationObserver = new MutationObserver((mutations) => {
          for (const mutation of mutations) {
            if (mutation.type === "childList") {
              const newElement = document.querySelector(selector);

              if (newElement) {
                cancel(timeoutTimer); // cancel the timeout timer
                forceFocus(newElement); // force focus on the target element
                resolve(true);

                // skip the rest of the mutations
                return;
              }
            }
          }
        });

        this.#mutationObserver.observe(document.querySelector("#main-outlet"), {
          childList: true,
          subtree: true,
        });
      });
    } finally {
      this.#mutationObserver?.disconnect();
      this.#mutationObserver = null;
    }
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
