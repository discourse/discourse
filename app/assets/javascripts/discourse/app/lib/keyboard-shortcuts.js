import { bind } from "discourse-common/utils/decorators";
import discourseDebounce from "discourse-common/lib/debounce";
import { isAppWebview } from "discourse/lib/utilities";
import { later, run, throttle } from "@ember/runloop";
import {
  nextTopicUrl,
  previousTopicUrl,
} from "discourse/lib/topic-list-tracker";
import Composer from "discourse/models/composer";
import DiscourseURL from "discourse/lib/url";
import domUtils from "discourse-common/utils/dom-utils";
import { INPUT_DELAY } from "discourse-common/config/environment";
import { ajax } from "discourse/lib/ajax";
import { headerOffset } from "discourse/lib/offset-calculator";

const DEFAULT_BINDINGS = {
  "!": { postAction: "showFlags" },
  "#": { handler: "goToPost", anonymous: true },
  "/": { handler: "toggleSearch", anonymous: true },
  "ctrl+alt+f": { handler: "toggleSearch", anonymous: true, global: true },
  "=": { handler: "toggleHamburgerMenu", anonymous: true },
  "?": { handler: "showHelpModal", anonymous: true },
  ".": { click: ".alert.alert-info.clickable", anonymous: true }, // show incoming/updated topics
  b: { handler: "toggleBookmark" },
  c: { handler: "createTopic" },
  "shift+c": { handler: "focusComposer" },
  "ctrl+f": { handler: "showPageSearch", anonymous: true },
  "command+f": { handler: "showPageSearch", anonymous: true },
  "command+left": { handler: "webviewKeyboardBack", anonymous: true },
  "command+[": { handler: "webviewKeyboardBack", anonymous: true },
  "command+right": { handler: "webviewKeyboardForward", anonymous: true },
  "command+]": { handler: "webviewKeyboardForward", anonymous: true },
  "mod+p": { handler: "printTopic", anonymous: true },
  d: { postAction: "deletePost" },
  e: { handler: "editPost" },
  end: { handler: "goToLastPost", anonymous: true },
  "command+down": { handler: "goToLastPost", anonymous: true },
  f: { handler: "toggleBookmarkTopic" },
  "g h": { path: "/", anonymous: true },
  "g l": { path: "/latest", anonymous: true },
  "g n": { path: "/new" },
  "g u": { path: "/unread" },
  "g c": { path: "/categories", anonymous: true },
  "g t": { path: "/top", anonymous: true },
  "g b": { path: "/my/activity/bookmarks" },
  "g p": { path: "/my/activity" },
  "g m": { path: "/my/messages" },
  "g d": { path: "/my/activity/drafts" },
  "g s": { handler: "goToFirstSuggestedTopic", anonymous: true },
  "g j": { handler: "goToNextTopic", anonymous: true },
  "g k": { handler: "goToPreviousTopic", anonymous: true },
  home: { handler: "goToFirstPost", anonymous: true },
  "command+up": { handler: "goToFirstPost", anonymous: true },
  j: { handler: "selectDown", anonymous: true },
  k: { handler: "selectUp", anonymous: true },
  // we use this odd routing here vs a postAction: cause like
  // has an animation so the widget handles that
  // TODO: teach controller how to trigger the widget animation
  l: { click: ".topic-post.selected button.toggle-like" },
  "m m": { handler: "setTrackingToMuted" }, // mark topic as muted
  "m r": { handler: "setTrackingToRegular" }, // mark topic as regular
  "m t": { handler: "setTrackingToTracking" }, // mark topic as tracking
  "m w": { handler: "setTrackingToWatching" }, // mark topic as watching
  "o,enter": {
    click: [
      ".topic-list tr.selected a.title",
      ".latest-topic-list .latest-topic-list-item.selected div.main-link a.title",
      ".top-topic-list .latest-topic-list-item.selected div.main-link a.title",
      ".latest .featured-topic.selected a.title",
      ".search-results .fps-result.selected .search-link",
    ].join(", "),
    anonymous: true,
  }, // open selected topic on latest or categories page
  tab: { handler: "switchFocusCategoriesPage", anonymous: true },
  p: { handler: "showCurrentUser" },
  q: { handler: "quoteReply" },
  r: { postAction: "replyToPost" },
  s: { click: ".topic-post.selected a.post-date", anonymous: true }, // share post
  "shift+j": { handler: "nextSection", anonymous: true },
  "shift+k": { handler: "prevSection", anonymous: true },
  "shift+p": { handler: "pinUnpinTopic" },
  "shift+r": { handler: "replyToTopic" },
  "shift+s": { click: "#topic-footer-buttons button.share", anonymous: true }, // share topic
  "shift+l": { handler: "goToUnreadPost" },
  "shift+z shift+z": { handler: "logout" },
  "shift+f11": { handler: "fullscreenComposer", global: true },
  "shift+u": { handler: "deferTopic" },
  "shift+a": { handler: "toggleAdminActions" },
  t: { postAction: "replyAsNewTopic" },
  u: { handler: "goBack", anonymous: true },
  "x r": {
    click: "#dismiss-new-bottom,#dismiss-new-top",
  }, // dismiss new
  "x t": { click: "#dismiss-topics-bottom,#dismiss-topics-top" }, // dismiss topics
};

const animationDuration = 100;

function preventKeyboardEvent(event) {
  event.preventDefault();
  event.stopPropagation();
}

export default {
  init(keyTrapper, container) {
    // Sometimes the keyboard shortcut initializer is not torn down. This makes sure
    // we clear any previous test state.
    if (this.keyTrapper) {
      this.keyTrapper.destroy();
      this.keyTrapper = null;
    }

    this.keyTrapper = new keyTrapper();
    this.container = container;
    this._stopCallback();

    this.searchService = this.container.lookup("service:search");
    this.appEvents = this.container.lookup("service:app-events");
    this.currentUser = this.container.lookup("current-user:main");
    this.siteSettings = this.container.lookup("site-settings:main");

    // Disable the shortcut if private messages are disabled
    if (!this.siteSettings.enable_personal_messages) {
      delete DEFAULT_BINDINGS["g m"];
    }
  },

  bindEvents() {
    Object.keys(DEFAULT_BINDINGS).forEach((key) => {
      this.bindKey(key);
    });
  },

  teardown() {
    this.keyTrapper?.destroy();
    this.keyTrapper = null;
    this.container = null;
  },

  isTornDown() {
    return this.keyTrapper == null || this.container == null;
  },

  bindKey(key, binding = null) {
    if (this.isTornDown()) {
      return;
    }

    if (!binding) {
      binding = DEFAULT_BINDINGS[key];
    }

    if (!binding.anonymous && !this.currentUser) {
      return;
    }

    if (binding.path) {
      this._bindToPath(binding.path, key);
    } else if (binding.handler) {
      if (binding.global) {
        // global shortcuts will trigger even while focusing on input/textarea
        this._globalBindToFunction(binding.handler, key);
      } else {
        this._bindToFunction(binding.handler, key);
      }
    } else if (binding.postAction) {
      this._bindToSelectedPost(binding.postAction, key);
    } else if (binding.click) {
      this._bindToClick(binding.click, key);
    }
  },

  // for cases when you want to disable global keyboard shortcuts
  // so that you can override them (e.g. inside a modal)
  pause(combinations) {
    if (this.isTornDown()) {
      return;
    }

    if (!combinations) {
      this.keyTrapper.paused = true;
      return;
    }
    combinations.forEach((combo) => this.keyTrapper.unbind(combo));
  },

  // restore global shortcuts that you have paused
  unpause(combinations) {
    if (this.isTornDown()) {
      return;
    }

    if (!combinations) {
      this.keyTrapper.paused = false;
      return;
    }

    combinations.forEach((combo) => this.bindKey(combo));
  },

  /**
   * addShortcut(shortcut, callback, opts)
   *
   * Used to bind a keyboard shortcut, which will fire the provided
   * callback when pressed. Valid options are:
   *
   * - global     - makes the shortcut work anywhere, including when an input is focused
   * - anonymous  - makes the shortcut work even if a user is not logged in
   * - path       - a specific path to limit the shortcut to .e.g /latest
   * - postAction - binds the shortcut to fire the specified post action when a
   *                post is selected
   * - click      - allows to provide a selector on which a click event
   *                will be triggered, eg: { click: ".topic.last .title" }
   **/
  addShortcut(shortcut, callback, opts = {}) {
    // we trim but leave whitespace between characters, as shortcuts
    // like `z z` are valid for ItsATrap
    shortcut = shortcut.trim();
    let newBinding = Object.assign({ handler: callback }, opts);
    this.bindKey(shortcut, newBinding);
  },

  // unbinds all the shortcuts in a key binding object e.g.
  // {
  //   'c': createTopic
  // }
  unbind(combinations) {
    Object.keys(combinations).forEach((combo) => this.keyTrapper.unbind(combo));
  },

  toggleBookmark(event) {
    const selectedPost = this._getSelectedPost();
    if (selectedPost) {
      preventKeyboardEvent(event);
      this.sendToSelectedPost("toggleBookmark", selectedPost);
      return;
    }

    const selectedTopicListItem = this._getSelectedTopicListItem();
    if (selectedTopicListItem) {
      preventKeyboardEvent(event);
      this.sendToTopicListItemView("toggleBookmark", selectedTopicListItem);
      return;
    }

    this._bookmarkCurrentTopic(event);
  },

  toggleBookmarkTopic(event) {
    const selectedTopicListItem = this._getSelectedTopicListItem();
    if (selectedTopicListItem) {
      preventKeyboardEvent(event);
      this.sendToTopicListItemView("toggleBookmark", selectedTopicListItem);
      return;
    }

    this._bookmarkCurrentTopic(event);
  },

  _bookmarkCurrentTopic(event) {
    const topic = this.currentTopic();
    if (topic && document.querySelectorAll(".posts-wrapper").length) {
      preventKeyboardEvent(event);
      this.container.lookup("controller:topic").send("toggleBookmark");
    }
  },

  logout() {
    this.container.lookup("route:application").send("logout");
  },

  quoteReply() {
    if (this.isPostTextSelected()) {
      this.appEvents.trigger("quote-button:quote");
      return false;
    }

    this.sendToSelectedPost("replyToPost");
    // lazy but should work for now
    later(() => $(".d-editor .quote").click(), 500);

    return false;
  },

  editPost() {
    if (this.siteSettings.enable_fast_edit && this.isPostTextSelected()) {
      this.appEvents.trigger("quote-button:edit");
      return false;
    } else {
      this.sendToSelectedPost("editPost");
    }

    return false;
  },

  goToNextTopic() {
    nextTopicUrl().then((url) => {
      if (url) {
        DiscourseURL.routeTo(url);
      }
    });
  },

  goToPreviousTopic() {
    previousTopicUrl().then((url) => {
      if (url) {
        DiscourseURL.routeTo(url);
      }
    });
  },

  goToFirstSuggestedTopic() {
    const $el = $(".suggested-topics a.raw-topic-link:first");
    if ($el.length) {
      $el.click();
    } else {
      const controller = this.container.lookup("controller:topic");
      // Only the last page contains list of suggested topics.
      const url = `/t/${controller.get("model.id")}/last.json`;
      ajax(url).then((result) => {
        if (result.suggested_topics && result.suggested_topics.length > 0) {
          const topic = controller.store.createRecord(
            "topic",
            result.suggested_topics[0]
          );
          DiscourseURL.routeTo(topic.get("url"));
        }
      });
    }
  },

  goToFirstPost() {
    this._jumpTo("jumpTop");
  },

  goToLastPost() {
    this._jumpTo("jumpBottom");
  },

  goToUnreadPost() {
    this._jumpTo("jumpUnread");
  },

  _jumpTo(direction) {
    if ($(".container.posts").length) {
      this.container.lookup("controller:topic").send(direction);
    }
  },

  replyToTopic() {
    this._replyToPost();

    return false;
  },

  selectDown() {
    this._moveSelection(1);
  },

  selectUp() {
    this._moveSelection(-1);
  },

  goBack() {
    history.back();
  },

  nextSection() {
    this._changeSection(1);
  },

  prevSection() {
    this._changeSection(-1);
  },

  showPageSearch(event) {
    run(() => {
      this.appEvents.trigger("header:keyboard-trigger", {
        type: "page-search",
        event,
      });
    });
  },

  printTopic(event) {
    run(() => {
      if ($(".container.posts").length) {
        event.preventDefault(); // We need to stop printing the current page in Firefox
        this.container.lookup("controller:topic").print();
      }
    });
  },

  createTopic(event) {
    if (!(this.currentUser && this.currentUser.can_create_topic)) {
      return;
    }

    event.preventDefault();

    // If the page has a create-topic button, use it for context sensitive attributes like category
    let $createTopicButton = $("#create-topic");
    if ($createTopicButton.length) {
      $createTopicButton.click();
      return;
    }

    this.container.lookup("controller:composer").open({
      action: Composer.CREATE_TOPIC,
      draftKey: Composer.NEW_TOPIC_KEY,
    });
  },

  focusComposer(event) {
    const composer = this.container.lookup("controller:composer");
    if (event) {
      event.preventDefault();
      event.stopPropagation();
    }
    composer.focusComposer(event);
  },

  fullscreenComposer() {
    const composer = this.container.lookup("controller:composer");
    if (composer.get("model")) {
      composer.toggleFullscreen();
    }
  },

  pinUnpinTopic() {
    this.container.lookup("controller:topic").togglePinnedState();
  },

  goToPost(event) {
    preventKeyboardEvent(event);
    this.appEvents.trigger("topic:keyboard-trigger", { type: "jump" });
  },

  toggleSearch(event) {
    this.appEvents.trigger("header:keyboard-trigger", {
      type: "search",
      event,
    });

    return false;
  },

  toggleHamburgerMenu(event) {
    this.appEvents.trigger("header:keyboard-trigger", {
      type: "hamburger",
      event,
    });
  },

  showCurrentUser(event) {
    this.appEvents.trigger("header:keyboard-trigger", { type: "user", event });
  },

  showHelpModal() {
    this.container
      .lookup("controller:application")
      .send("showKeyboardShortcutsHelp");
  },

  setTrackingToMuted() {
    throttle(this, "_setTracking", 0, INPUT_DELAY, true);
  },

  setTrackingToRegular() {
    throttle(this, "_setTracking", 1, INPUT_DELAY, true);
  },

  setTrackingToTracking() {
    throttle(this, "_setTracking", 2, INPUT_DELAY, true);
  },

  setTrackingToWatching() {
    throttle(this, "_setTracking", 3, INPUT_DELAY, true);
  },

  _setTracking(levelId) {
    const topic = this.currentTopic();

    if (!topic) {
      return;
    }

    topic.details.updateNotifications(levelId);
  },

  sendToTopicListItemView(action, elem) {
    elem = elem || document.querySelector("tr.selected.topic-list-item");
    if (elem) {
      const registry = this.container.lookup("-view-registry:main");
      if (registry) {
        const view = registry[elem.id];
        view.send(action);
      }
    }
  },

  currentTopic() {
    const topicController = this.container.lookup("controller:topic");
    if (topicController) {
      const topic = topicController.get("model");
      if (topic) {
        return topic;
      }
    }
  },

  isPostTextSelected() {
    const topicController = this.container.lookup("controller:topic");
    return !!topicController?.get("quoteState")?.postId;
  },

  sendToSelectedPost(action, elem) {
    // TODO: We should keep track of the post without a CSS class
    const selectedPost =
      elem || document.querySelector(".topic-post.selected article.boxed");

    let selectedPostId;
    if (selectedPost) {
      selectedPostId = parseInt(selectedPost.dataset.postId, 10);
    }

    if (selectedPostId) {
      const topicController = this.container.lookup("controller:topic");
      const post = topicController
        .get("model.postStream.posts")
        .findBy("id", selectedPostId);
      if (post) {
        // TODO: Use ember closure actions

        let actionMethod = topicController.actions[action];
        if (!actionMethod) {
          const topicRoute = this.container.lookup("route:topic");
          actionMethod = topicRoute.actions[action];
        }

        const result = actionMethod.call(topicController, post);
        if (result && result.then) {
          this.appEvents.trigger("post-stream:refresh", { id: selectedPostId });
        }
      }
    }

    return false;
  },

  _bindToSelectedPost(action, binding) {
    this.keyTrapper.bind(binding, () => this.sendToSelectedPost(action));
  },

  _bindToPath(path, key) {
    this.keyTrapper.bind(key, () => DiscourseURL.routeTo(path));
  },

  _bindToClick(selector, binding) {
    binding = binding.split(",");
    this.keyTrapper.bind(binding, function (e) {
      const selection = document.querySelector(selector);

      // Special case: We're binding to enter.
      if (e && e.key === "Enter") {
        // Binding to enter should only be effective when there is something
        // to select.
        if (!selection) {
          return;
        }

        // If effective, prevent default.
        e.preventDefault();
      }

      selection?.click();
    });
  },

  _globalBindToFunction(func, binding) {
    let funcToBind = typeof func === "function" ? func : this[func];
    if (typeof funcToBind === "function") {
      this.keyTrapper.bindGlobal(binding, funcToBind.bind(this));
    }
  },

  _bindToFunction(func, binding) {
    let funcToBind = typeof func === "function" ? func : this[func];
    if (typeof funcToBind === "function") {
      this.keyTrapper.bind(binding, funcToBind.bind(this));
    }
  },

  _moveSelection(direction) {
    // Pressing a move key (J/K) very quick (i.e. keeping J or K pressed) will
    // move fast by disabling smooth page scrolling.
    const now = +new Date();
    const fast =
      this._lastMoveTime && now - this._lastMoveTime < 1.5 * animationDuration;
    this._lastMoveTime = now;

    const $articles = this._findArticles();
    if ($articles === undefined) {
      return;
    }

    let $selected = $articles.filter(".selected");
    if ($selected.length === 0) {
      $selected = $articles.filter("[data-islastviewedtopic=true]");
    }

    // Discard selection if it is not in viewport, so users can combine
    // keyboard shortcuts with mouse scrolling.
    if ($selected.length !== 0 && !fast) {
      const offset = headerOffset();
      const beginScreen = $(window).scrollTop() - offset;
      const endScreen = beginScreen + window.innerHeight + offset;
      const beginArticle = $selected.offset().top;
      const endArticle = $selected.offset().top + $selected.height();
      if (beginScreen > endArticle || beginArticle > endScreen) {
        $selected = null;
      }
    }

    // If still nothing is selected, select the first post that is
    // visible and cancel move operation.
    if (!$selected || $selected.length === 0) {
      const offset = headerOffset();
      $selected = $articles
        .toArray()
        .find((article) =>
          direction > 0
            ? article.getBoundingClientRect().top > offset
            : article.getBoundingClientRect().bottom > offset
        );
      if (!$selected) {
        $selected = $articles[$articles.length - 1];
      }
      direction = 0;
    }

    const index = $articles.index($selected);
    let article = $articles.eq(index)[0];

    // Try doing a page scroll in the context of current post.
    if (!fast && direction !== 0 && article) {
      // The beginning of first article is the beginning of the page.
      const beginArticle =
        article.classList.contains("topic-post") &&
        article.querySelector("#post_1")
          ? 0
          : domUtils.offset(article).top;
      const endArticle = domUtils.offset(article).top + article.offsetHeight;

      const beginScreen = window.scrollY;
      const endScreen = beginScreen + window.innerHeight;

      if (direction < 0 && beginScreen > beginArticle) {
        return this._scrollTo(
          Math.max(
            beginScreen - window.innerHeight + 3 * headerOffset(), // page up
            beginArticle - headerOffset() // beginning of article
          )
        );
      } else if (direction > 0 && endScreen < endArticle - headerOffset()) {
        return this._scrollTo(
          Math.min(
            endScreen - 3 * headerOffset(), // page down
            endArticle - window.innerHeight // end of article
          )
        );
      }
    }

    // Try scrolling to post above or below.
    if ($selected.length !== 0) {
      if (direction === -1 && index === 0) {
        return;
      }
      if (direction === 1 && index === $articles.length - 1) {
        return;
      }
    }

    article = $articles.eq(index + direction)[0];
    if (!article) {
      return;
    }

    $articles.removeClass("selected");
    article.classList.add("selected");

    this.appEvents.trigger("keyboard:move-selection", {
      articles: $articles.get(),
      selectedArticle: article,
    });

    const articleTop = domUtils.offset(article).top,
      articleTopPosition = articleTop - headerOffset();
    if (!fast && direction < 0 && article.offsetHeight > window.innerHeight) {
      // Scrolling to the last "page" of the previous post if post has multiple
      // "pages" (if its height does not fit in the screen).
      return this._scrollTo(
        articleTop + article.offsetHeight - window.innerHeight
      );
    } else if (article.classList.contains("topic-post")) {
      return this._scrollTo(
        article.querySelector("#post_1") ? 0 : articleTopPosition,
        { focusTabLoc: true }
      );
    }

    // Otherwise scroll through the topic list.
    if (
      articleTopPosition > window.pageYOffset &&
      articleTop + article.offsetHeight <
        window.pageYOffset + window.innerHeight
    ) {
      return;
    }

    const scrollRatio = direction > 0 ? 0.2 : 0.7;
    this._scrollTo(articleTopPosition - window.innerHeight * scrollRatio);
  },

  _scrollTo(scrollTop, opts = {}) {
    window.scrollTo({
      top: scrollTop,
      behavior: "smooth",
    });

    if (opts.focusTabLoc) {
      window.addEventListener("scroll", this._onScrollEnds, { passive: true });
    }
  },

  @bind
  _onScrollEnds() {
    window.removeEventListener("scroll", this._onScrollEnds, { passive: true });
    discourseDebounce(this, this._onScrollEndsCallback, animationDuration);
  },

  _onScrollEndsCallback() {
    document.querySelector(".topic-post.selected a.tabLoc")?.focus();
  },

  categoriesTopicsList() {
    switch (this.siteSettings.desktop_category_page_style) {
      case "categories_with_featured_topics":
        return $(".latest .featured-topic");
      case "categories_and_latest_topics":
        return $(".latest-topic-list .latest-topic-list-item");
      case "categories_and_top_topics":
        return $(".top-topic-list .latest-topic-list-item");
      default:
        return $();
    }
  },

  _findArticles() {
    const $topicList = $(".topic-list");
    const $postsWrapper = $(".posts-wrapper");
    const $categoriesTopicsList = this.categoriesTopicsList();
    const $searchResults = $(".search-results");

    if ($postsWrapper.length > 0) {
      return $(".posts-wrapper .topic-post, .topic-list tbody tr");
    } else if ($topicList.length > 0) {
      return $topicList.find(".topic-list-item");
    } else if ($categoriesTopicsList.length > 0) {
      return $categoriesTopicsList;
    } else if ($searchResults.length > 0) {
      return $searchResults.find(".fps-result");
    }
  },

  _changeSection(direction) {
    const $sections = $(".nav.nav-pills li"),
      active = $(".nav.nav-pills li.active"),
      index = $sections.index(active) + direction;

    if (index >= 0 && index < $sections.length) {
      $sections.eq(index).find("a").click();
    }
  },

  _stopCallback() {
    const prototype = Object.getPrototypeOf(this.keyTrapper);
    const oldStopCallback = prototype.stopCallback;

    prototype.stopCallback = function (e, element, combo, sequence) {
      if (this.paused) {
        return true;
      }

      if (
        (combo === "ctrl+f" || combo === "command+f") &&
        element.id === "search-term"
      ) {
        return false;
      }

      return oldStopCallback.call(this, e, element, combo, sequence);
    };
  },

  _replyToPost() {
    this.container.lookup("controller:topic").send("replyToPost");
  },

  _getSelectedPost() {
    return document.querySelector(".topic-post.selected article[data-post-id]");
  },

  _getSelectedTopicListItem() {
    return document.querySelector("tr.selected.topic-list-item");
  },

  deferTopic() {
    this.container.lookup("controller:topic").send("deferTopic");
  },

  toggleAdminActions() {
    this.appEvents.trigger("topic:toggle-actions");
  },

  webviewKeyboardBack() {
    if (isAppWebview()) {
      window.history.back();
    }
  },

  webviewKeyboardForward() {
    if (isAppWebview()) {
      window.history.forward();
    }
  },
};
