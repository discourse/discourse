import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import a11ySkipLink from "discourse/helpers/a11y-skip-link";
import { i18n } from "discourse-i18n";

class TopicSkipLinks extends Component {
  @service router;
  @service appEvents;

  #skipLinkFocusListener = null;

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

  get topicUrl() {
    const topicId = this.args.topic.id;
    const topicSlug = this.args.topic.slug;

    if (topicId && topicSlug) {
      return `/t/${topicSlug}/${topicId}`;
    }
    return topicId ? `/t/${topicId}` : null;
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

  #setupFocusAfterNavigation(focusCallback) {
    if (focusCallback()) {
      return;
    }

    let attempts = 0;
    const maxAttempts = 20;

    const tryFocus = () => {
      attempts++;
      if (focusCallback()) {
        if (this.#skipLinkFocusListener) {
          this.appEvents.off(
            "post-stream:posts-appended",
            this,
            this.#skipLinkFocusListener
          );
          this.#skipLinkFocusListener = null;
        }
        return;
      }

      if (attempts >= maxAttempts) {
        if (this.#skipLinkFocusListener) {
          this.appEvents.off(
            "post-stream:posts-appended",
            this,
            this.#skipLinkFocusListener
          );
          this.#skipLinkFocusListener = null;
        }
        return;
      }

      setTimeout(tryFocus, 500);
    };

    this.#skipLinkFocusListener = () => {
      setTimeout(tryFocus, 100);
    };

    this.appEvents.on(
      "post-stream:posts-appended",
      this,
      this.#skipLinkFocusListener
    );

    setTimeout(tryFocus, 500);
  }

  @action
  handleSkipToTop() {
    setTimeout(() => {
      const topicTitle =
        document.querySelector("h1[data-topic-title]") ||
        document.querySelector(".topic-title h1") ||
        document.querySelector("#topic-title") ||
        document.querySelector("h1");

      if (topicTitle) {
        topicTitle.setAttribute("tabindex", "-1");
        topicTitle.focus();
      }
    }, 500);
  }

  @action
  handleSkipToPost() {
    this.#setupFocusAfterNavigation(() => {
      const currentPost = this.currentPostNumber;
      if (!currentPost) {
        return false;
      }

      const postHeading =
        document.querySelector(
          `[data-post-number="${currentPost}"] .post-username`
        ) ||
        document.querySelector(
          `[data-post-number="${currentPost}"] .username`
        ) ||
        document.querySelector(`[data-post-number="${currentPost}"]`);

      if (postHeading) {
        postHeading.setAttribute("tabindex", "-1");
        postHeading.focus();
        return true;
      } else {
        return false;
      }
    });
  }

  @action
  handleSkipToLastPost() {
    this.#setupFocusAfterNavigation(() => {
      const lastPostNumber = this.lastPostNumber;
      if (!lastPostNumber) {
        return false;
      }

      const postHeading =
        document.querySelector(
          `[data-post-number="${lastPostNumber}"] .post-username`
        ) ||
        document.querySelector(
          `[data-post-number="${lastPostNumber}"] .username`
        ) ||
        document.querySelector(`[data-post-number="${lastPostNumber}"]`);

      if (postHeading) {
        postHeading.setAttribute("tabindex", "-1");
        postHeading.focus();
        return true;
      } else {
        return false;
      }
    });
  }

  @action
  handleSkipToResume() {
    this.#setupFocusAfterNavigation(() => {
      const resumePostNumber = this.resumePostNumber;
      if (!resumePostNumber) {
        return false;
      }

      const postHeading =
        document.querySelector(
          `[data-post-number="${resumePostNumber}"] .post-username`
        ) ||
        document.querySelector(
          `[data-post-number="${resumePostNumber}"] .username`
        ) ||
        document.querySelector(`[data-post-number="${resumePostNumber}"]`);

      if (postHeading) {
        postHeading.setAttribute("tabindex", "-1");
        postHeading.focus();
        return true;
      } else {
        return false;
      }
    });
  }

  <template>
    {{#if this.showTopicSkipLinks}}
      {{#if this.isDirectUrlToArbitraryPost}}
        {{a11ySkipLink
          href=(concat this.topicUrl "/" this.currentPostNumber)
          label=(i18n "skip_to_post" post_number=this.currentPostNumber)
          onClick=this.handleSkipToPost
          position="topic-001"
        }}
      {{/if}}
      {{#if this.resumePostNumber}}
        {{#if this.resumeIsLastReply}}
          {{a11ySkipLink
            href=(concat this.topicUrl "/last")
            label=(i18n
              "skip_to_where_you_left_off_last"
              post_number=this.resumePostNumber
            )
            onClick=this.handleSkipToResume
            position="topic-002"
          }}
        {{else}}
          {{a11ySkipLink
            href=(concat this.topicUrl "/" this.resumePostNumber)
            label=(i18n
              "skip_to_where_you_left_off" post_number=this.resumePostNumber
            )
            onClick=this.handleSkipToResume
            position="topic-003"
          }}
          {{#if this.topicHasMultiplePosts}}
            {{a11ySkipLink
              href=(concat this.topicUrl "/last")
              label=(i18n "skip_to_last_reply")
              onClick=this.handleSkipToLastPost
              position="topic-004"
            }}
          {{/if}}
        {{/if}}
      {{else}}
        {{#if this.topicHasMultiplePosts}}
          {{a11ySkipLink
            href=(concat this.topicUrl "/last")
            label=(i18n "skip_to_last_reply")
            onClick=this.handleSkipToLastPost
            position="topic-005"
          }}
        {{/if}}
      {{/if}}
      {{#if this.topicHasMultiplePosts}}
        {{a11ySkipLink
          href=(concat this.topicUrl "/1")
          label=(i18n "skip_to_top")
          onClick=this.handleSkipToTop
          position="topic-006"
        }}
      {{/if}}
    {{/if}}
  </template>
}

export default TopicSkipLinks;
