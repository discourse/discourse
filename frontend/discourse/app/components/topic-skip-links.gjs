import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

class TopicSkipLinks extends Component {
  @service router;
  @service appEvents;

  #skipLinkFocusListener = null;

  get applicationController() {
    return getOwner(this).lookup("controller:application");
  }

  #getTopicController() {
    if (!this.router.currentRouteName?.startsWith("topic.")) {
      return null;
    }
    try {
      return getOwner(this).lookup("controller:topic");
    } catch {
      return null;
    }
  }

  get showTopicSkipLinks() {
    const topicController = this.#getTopicController();
    return (
      topicController?.userLastReadPostNumber &&
      topicController.userLastReadPostNumber > 0
    );
  }

  get resumePostNumber() {
    const topicController = this.#getTopicController();
    if (
      topicController?.userLastReadPostNumber &&
      topicController.userLastReadPostNumber > 1
    ) {
      return topicController.userLastReadPostNumber;
    }
    return null;
  }

  get lastPostNumber() {
    const topicController = this.#getTopicController();
    return (
      topicController?.get("model.highest_post_number") ||
      topicController?.get("model.posts_count") ||
      null
    );
  }

  get topicUrl() {
    const topicController = this.#getTopicController();
    const topicId = topicController?.get("model.id");
    const topicSlug = topicController?.get("model.slug");

    if (topicId && topicSlug) {
      return `/t/${topicSlug}/${topicId}`;
    }
    return topicId ? `/t/${topicId}` : null;
  }

  get resumeIsLastReply() {
    const topicController = this.#getTopicController();
    if (!topicController) {
      return false;
    }

    const resumePostNumber = topicController.userLastReadPostNumber;
    const lastPostNumber =
      topicController.get("model.highest_post_number") ||
      topicController.get("model.posts_count");

    return (
      resumePostNumber && lastPostNumber && resumePostNumber >= lastPostNumber
    );
  }

  get topicHasMultiplePosts() {
    const topicController = this.#getTopicController();
    const postsCount = topicController?.get("model.posts_count");
    return postsCount && postsCount > 1;
  }

  get currentPostNumber() {
    const topicController = this.#getTopicController();
    return (
      topicController?.get("currentPost") ||
      topicController?.get("model.currentPost") ||
      parseInt(this.router.currentRoute?.params?.nearPost, 10) ||
      1
    );
  }

  get isDirectUrlToArbitraryPost() {
    const topicController = this.#getTopicController();
    if (!topicController) {
      return false;
    }

    const currentPost = this.currentPostNumber;
    const resumePost = topicController.userLastReadPostNumber;

    return (
      currentPost && currentPost > 1 && resumePost && currentPost !== resumePost
    );
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
    {{#if this.applicationController.showSkipToContent}}
      {{#if this.showTopicSkipLinks}}
        <div class="skip-links" aria-label={{i18n "skip_links_label"}}>
          {{#if this.isDirectUrlToArbitraryPost}}
            <a
              href="{{this.topicUrl}}/{{this.currentPostNumber}}"
              class="skip-link"
              {{on "click" this.handleSkipToPost}}
            >
              {{i18n "skip_to_post" post_number=this.currentPostNumber}}
            </a>
          {{/if}}
          {{#if this.resumePostNumber}}
            {{#if this.resumeIsLastReply}}
              <a
                href="{{this.topicUrl}}/last"
                class="skip-link"
                {{on "click" this.handleSkipToResume}}
              >
                {{i18n
                  "skip_to_where_you_left_off_last"
                  post_number=this.resumePostNumber
                }}
              </a>
            {{else}}
              <a
                href="{{this.topicUrl}}/{{this.resumePostNumber}}"
                class="skip-link"
                {{on "click" this.handleSkipToResume}}
              >
                {{i18n
                  "skip_to_where_you_left_off"
                  post_number=this.resumePostNumber
                }}
              </a>
              {{#if this.topicHasMultiplePosts}}
                <a
                  href="{{this.topicUrl}}/last"
                  class="skip-link"
                  {{on "click" this.handleSkipToLastPost}}
                >{{i18n "skip_to_last_reply"}}</a>
              {{/if}}
            {{/if}}
          {{else}}
            {{#if this.topicHasMultiplePosts}}
              <a
                href="{{this.topicUrl}}/last"
                class="skip-link"
                {{on "click" this.handleSkipToLastPost}}
              >{{i18n "skip_to_last_reply"}}</a>
            {{/if}}
          {{/if}}
          {{#if this.topicHasMultiplePosts}}
            <a
              href="{{this.topicUrl}}/1"
              class="skip-link"
              {{on "click" this.handleSkipToTop}}
            >{{i18n "skip_to_top"}}</a>
          {{/if}}
          <a href="#main-container" class="skip-link">{{i18n
              "skip_to_main_content"
            }}</a>
        </div>
      {{else}}
        <a href="#main-container" class="skip-link">{{i18n
            "skip_to_main_content"
          }}</a>
      {{/if}}
    {{/if}}
  </template>
}

export default TopicSkipLinks;
