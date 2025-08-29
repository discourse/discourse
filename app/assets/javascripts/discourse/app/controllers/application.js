import Controller from "@ember/controller";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import runAfterFramePaint from "discourse/lib/after-frame-paint";
import discourseDebounce from "discourse/lib/debounce";
import discourseComputed from "discourse/lib/decorators";
import deprecated from "discourse/lib/deprecated";
import { isTesting } from "discourse/lib/environment";

const HIDE_SIDEBAR_KEY = "sidebar-hidden";

export default class ApplicationController extends Controller {
  @service router;
  @service footer;
  @service header;
  @service sidebarState;
  @service appEvents;
  @service accessibilityAnnouncer;

  queryParams = [{ navigationMenuQueryParamOverride: "navigation_menu" }];
  showTop = true;

  showSidebar = this.calculateShowSidebar();
  sidebarDisabledRouteOverride = false;
  navigationMenuQueryParamOverride = null;
  showSiteHeader = true;
  showSkipToContent = true;

  #skipLinkFocusListener = null;

  @discourseComputed("router.currentRouteName")
  showTopicSkipLinks(currentRouteName) {
    if (!currentRouteName || !currentRouteName.startsWith("topic.")) {
      return false;
    }

    // Only show topic skip links if the user has read the topic before
    try {
      const topicController = getOwner(this).lookup("controller:topic");
      return (
        topicController?.userLastReadPostNumber &&
        topicController.userLastReadPostNumber > 0
      );
    } catch {
      // Ignore if controller doesn't exist yet
      return false;
    }
  }

  @discourseComputed("router.currentRouteName")
  resumePostNumber(currentRouteName) {
    if (!currentRouteName || !currentRouteName.startsWith("topic.")) {
      return null;
    }

    // Only show "skip to where you left off" if not at the beginning
    try {
      const topicController = getOwner(this).lookup("controller:topic");
      if (
        topicController?.userLastReadPostNumber &&
        topicController.userLastReadPostNumber > 1
      ) {
        return topicController.userLastReadPostNumber;
      }
    } catch {
      // Ignore if controller doesn't exist yet
    }

    return null;
  }

  @discourseComputed("router.currentRouteName")
  lastPostNumber(currentRouteName) {
    if (!currentRouteName || !currentRouteName.startsWith("topic.")) {
      return null;
    }

    try {
      const topicController = getOwner(this).lookup("controller:topic");
      return (
        topicController?.get("model.highest_post_number") ||
        topicController?.get("model.posts_count")
      );
    } catch {
      // Ignore if controller doesn't exist yet
      return null;
    }
  }

  @discourseComputed("router.currentRouteName")
  topicUrl(currentRouteName) {
    if (!currentRouteName || !currentRouteName.startsWith("topic.")) {
      return null;
    }

    try {
      const topicController = getOwner(this).lookup("controller:topic");
      const topicId = topicController?.get("model.id");
      const topicSlug = topicController?.get("model.slug");

      if (topicId && topicSlug) {
        return `/t/${topicSlug}/${topicId}`;
      }
      return topicId ? `/t/${topicId}` : null;
    } catch {
      // Ignore if controller doesn't exist yet
      return null;
    }
  }

  @discourseComputed("router.currentRouteName")
  resumeIsLastReply(currentRouteName) {
    if (!currentRouteName || !currentRouteName.startsWith("topic.")) {
      return false;
    }

    try {
      const topicController = getOwner(this).lookup("controller:topic");
      const resumePostNumber = topicController?.userLastReadPostNumber;
      const lastPostNumber =
        topicController?.get("model.highest_post_number") ||
        topicController?.get("model.posts_count");

      return (
        resumePostNumber && lastPostNumber && resumePostNumber >= lastPostNumber
      );
    } catch {
      // Ignore if controller doesn't exist yet
      return false;
    }
  }

  @discourseComputed("router.currentRouteName")
  topicHasMultiplePosts(currentRouteName) {
    if (!currentRouteName || !currentRouteName.startsWith("topic.")) {
      return false;
    }

    try {
      const topicController = getOwner(this).lookup("controller:topic");
      const postsCount = topicController?.get("model.posts_count");
      return postsCount && postsCount > 1;
    } catch {
      return false;
    }
  }

  @discourseComputed("router.currentRouteName")
  currentPostNumber(currentRouteName) {
    if (!currentRouteName || !currentRouteName.startsWith("topic.")) {
      return null;
    }

    try {
      const topicController = getOwner(this).lookup("controller:topic");
      return (
        topicController?.get("currentPost") ||
        topicController?.get("model.currentPost") ||
        parseInt(this.router.currentRoute?.params?.nearPost, 10) ||
        1
      );
    } catch {
      return null;
    }
  }

  @discourseComputed("router.currentRouteName")
  isDirectUrlToArbitraryPost(currentRouteName) {
    if (!currentRouteName || !currentRouteName.startsWith("topic.")) {
      return false;
    }

    try {
      const topicController = getOwner(this).lookup("controller:topic");
      const currentPost = this.currentPostNumber;
      const resumePost = topicController?.userLastReadPostNumber;

      // Show skip link if we're at a direct URL that's not where they left off
      // and not at the beginning (post 1)
      return (
        currentPost &&
        currentPost > 1 &&
        resumePost &&
        currentPost !== resumePost
      );
    } catch {
      return false;
    }
  }

  get showFooter() {
    return this.footer.showFooter;
  }

  set showFooter(value) {
    deprecated(
      "showFooter state is now stored in the `footer` service, and should be controlled by adding the {{hide-application-footer}} helper to an Ember template.",
      { id: "discourse.application-show-footer" }
    );
    this.footer.showFooter = value;
  }

  get showPoweredBy() {
    return this.showFooter && this.siteSettings.enable_powered_by_discourse;
  }

  @discourseComputed
  canSignUp() {
    return (
      !this.siteSettings.invite_only &&
      this.siteSettings.allow_new_registrations &&
      !this.siteSettings.enable_discourse_connect
    );
  }

  @discourseComputed
  canDisplaySidebar() {
    return this.currentUser || !this.siteSettings.login_required;
  }

  @discourseComputed
  loginRequired() {
    return this.siteSettings.login_required && !this.currentUser;
  }

  @discourseComputed
  showFooterNav() {
    return this.capabilities.isAppWebview || this.capabilities.isiOSPWA;
  }

  #setupFocusAfterNavigation(focusCallback) {
    // Try immediate focus first
    if (focusCallback()) {
      return;
    }

    // If that fails, wait for posts to load
    let attempts = 0;
    const maxAttempts = 20; // 10 seconds max wait

    const tryFocus = () => {
      attempts++;
      if (focusCallback()) {
        // Success
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
        // Gave up waiting for post to appear for focus management
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

      // Wait a bit longer and try again
      setTimeout(tryFocus, 500);
    };

    // Set up event listener for when posts are appended
    this.#skipLinkFocusListener = () => {
      setTimeout(tryFocus, 100); // Small delay after posts appended
    };

    this.appEvents.on(
      "post-stream:posts-appended",
      this,
      this.#skipLinkFocusListener
    );

    // Also try again after a short delay
    setTimeout(tryFocus, 500);
  }

  @action
  handleSkipToTop() {
    // Focus the topic title after navigation completes
    setTimeout(() => {
      const topicTitle =
        document.querySelector("h1[data-topic-title]") ||
        document.querySelector(".topic-title h1") ||
        document.querySelector("#topic-title") ||
        document.querySelector("h1");

      if (topicTitle) {
        // Make it focusable and focus it
        topicTitle.setAttribute("tabindex", "-1");
        topicTitle.focus();
        // Focused topic title after skip to top
      } else {
        // Could not find topic title to focus
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
        // Focused post ${currentPost} after skip to post
        return true;
      } else {
        // Could not find post ${currentPost} to focus
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
        // Focused last post ${lastPostNumber} after skip to last
        return true;
      } else {
        // Could not find last post ${lastPostNumber} to focus
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
        // Focused resume post ${resumePostNumber} after skip to resume
        return true;
      } else {
        // Could not find resume post ${resumePostNumber} to focus
        return false;
      }
    });
  }

  _mainOutletAnimate() {
    document.body.classList.remove("sidebar-animate");
  }

  get sidebarEnabled() {
    if (!this.canDisplaySidebar) {
      return false;
    }

    if (this.sidebarState.sidebarHidden) {
      return false;
    }

    if (this.sidebarDisabledRouteOverride) {
      return false;
    }

    if (this.navigationMenuQueryParamOverride === "sidebar") {
      return true;
    }

    if (this.navigationMenuQueryParamOverride === "header_dropdown") {
      return false;
    }

    // Always return dropdown on mobile
    if (this.site.mobileView) {
      return false;
    }

    // Always show sidebar for admin if user can see the admin sidebar
    if (this.sidebarState.isForcingSidebar) {
      return true;
    }

    return this.siteSettings.navigation_menu === "sidebar";
  }

  calculateShowSidebar() {
    return (
      this.canDisplaySidebar &&
      !this.keyValueStore.getItem(HIDE_SIDEBAR_KEY) &&
      !this.site.narrowDesktopView
    );
  }

  @action
  toggleSidebar() {
    // enables CSS transitions, but not on did-insert
    document.body.classList.add("sidebar-animate");

    discourseDebounce(this, this._mainOutletAnimate, 250);

    this.toggleProperty("showSidebar");

    if (this.site.desktopView) {
      if (this.showSidebar) {
        this.keyValueStore.removeItem(HIDE_SIDEBAR_KEY);
      } else {
        this.keyValueStore.setItem(HIDE_SIDEBAR_KEY, "true");
      }
    }
  }

  @action
  trackDiscoursePainted() {
    if (isTesting()) {
      return;
    }
    runAfterFramePaint(() => {
      performance.mark("discourse-paint");
      try {
        performance.measure(
          "discourse-init-to-paint",
          "discourse-init",
          "discourse-paint"
        );
      } catch (e) {
        // eslint-disable-next-line no-console
        console.warn("Failed to measure init-to-paint", e);
      }
    });
  }
}
