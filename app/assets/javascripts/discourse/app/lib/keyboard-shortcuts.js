import { getOwner, setOwner } from "@ember/owner";
import { run, throttle } from "@ember/runloop";
import { ajax } from "discourse/lib/ajax";
import { headerOffset } from "discourse/lib/offset-calculator";
import {
  nextTopicUrl,
  previousTopicUrl,
} from "discourse/lib/topic-list-tracker";
import DiscourseURL from "discourse/lib/url";
import Composer from "discourse/models/composer";
import { capabilities } from "discourse/services/capabilities";
import { INPUT_DELAY } from "discourse-common/config/environment";
import discourseLater from "discourse-common/lib/later";
import domUtils from "discourse-common/utils/dom-utils";

let disabledBindings = [];
export function disableDefaultKeyboardShortcuts(bindings) {
  disabledBindings = disabledBindings.concat(bindings);
}

export function clearDisabledDefaultKeyboardBindings() {
  disabledBindings = [];
}

let extraKeyboardShortcutsHelp = {};
function addExtraKeyboardShortcutHelp(help) {
  const category = help.category;
  if (extraKeyboardShortcutsHelp[category]) {
    extraKeyboardShortcutsHelp[category] = extraKeyboardShortcutsHelp[
      category
    ].concat([help]);
  } else {
    extraKeyboardShortcutsHelp[category] = [help];
  }
}

export function clearExtraKeyboardShortcutHelp() {
  extraKeyboardShortcutsHelp = {};
}

export { extraKeyboardShortcutsHelp as extraKeyboardShortcutsHelp };

export const PLATFORM_KEY_MODIFIER = /Mac|iPod|iPhone|iPad/.test(
  navigator.platform
)
  ? "meta"
  : "ctrl";

const DEFAULT_BINDINGS = {
  "!": { postAction: "showFlags" },
  "#": { handler: "goToPost", anonymous: true },
  "/": { handler: "toggleSearch", anonymous: true },
  "meta+/": { handler: "filterSidebar", anonymous: true },
  [`${PLATFORM_KEY_MODIFIER}+/`]: { handler: "filterSidebar", anonymous: true },
  "ctrl+alt+f": { handler: "toggleSearch", anonymous: true, global: true },
  "=": { handler: "toggleHamburgerMenu", anonymous: true },
  "?": { handler: "showHelpModal", anonymous: true },
  ".": { click: ".alert.alert-info.clickable", anonymous: true }, // show incoming/updated topics
  a: { handler: "toggleArchivePM" },
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
  d: { postAction: "deletePostWithConfirmation" },
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
  "shift+s": {
    click: "#topic-footer-buttons button.share-and-invite",
    anonymous: true,
  }, // share topic
  "shift+l": { handler: "goToUnreadPost" },
  "shift+z shift+z": { handler: "logout" },
  "shift+f11": { handler: "fullscreenComposer", global: true },
  "shift+u": { handler: "deferTopic" },
  "shift+a": { handler: "toggleAdminActions" },
  "shift+b": { handler: "toggleBulkSelect" },
  t: { postAction: "replyAsNewTopic" },
  u: { handler: "goBack", anonymous: true },
  x: { handler: "bulkSelectItem" },
  "shift+d": {
    click:
      "#dismiss-new-bottom, #dismiss-new-top, #dismiss-topics-bottom, #dismiss-topics-top",
  }, // dismiss new or unread
};

const animationDuration = 100;

function preventKeyboardEvent(event) {
  event.preventDefault();
  event.stopPropagation();
}

export default {
  init(keyTrapper, owner) {
    setOwner(this, owner);

    // Sometimes the keyboard shortcut initializer is not torn down. This makes sure
    // we clear any previous test state.
    if (this.keyTrapper) {
      this.keyTrapper.destroy();
      this.keyTrapper = null;
    }

    this.keyTrapper = new keyTrapper();
    this._stopCallback();

    this.searchService = owner.lookup("service:search");
    this.appEvents = owner.lookup("service:app-events");
    this.currentUser = owner.lookup("service:current-user");
    this.siteSettings = owner.lookup("service:site-settings");
    this.site = owner.lookup("service:site");

    // Disable the shortcut if private messages are disabled
    if (!this.currentUser?.can_send_private_messages) {
      delete DEFAULT_BINDINGS["g m"];
    }

    if (disabledBindings.length) {
      disabledBindings.forEach((binding) => delete DEFAULT_BINDINGS[binding]);
    }
  },

  bindEvents() {
    Object.keys(DEFAULT_BINDINGS).forEach((key) => {
      this.bindKey(key);
    });
  },

  teardown() {
    const prototype = Object.getPrototypeOf(this.keyTrapper);
    prototype.stopCallback = this.oldStopCallback;
    this.oldStopCallback = null;

    this.keyTrapper?.destroy();
    this.keyTrapper = null;
  },

  isTornDown() {
    return this.keyTrapper == null;
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
   * - help       - adds the shortcut to the keyboard shortcuts modal. `help` is an object
   *                with key/value pairs
   *                {
   *                  category: String,
   *                  name: String,
   *                  definition: (See function `buildShortcut` in
   *                    app/assets/javascripts/discourse/app/controllers/keyboard-shortcuts-help.js
   *                    for definition structure)
   *                }
   *
   * - click      - allows to provide a selector on which a click event
   *                will be triggered, eg: { click: ".topic.last .title" }
   **/
  addShortcut(shortcut, callback, opts = {}) {
    // we trim but leave whitespace between characters, as shortcuts
    // like `z z` are valid for ItsATrap
    shortcut = shortcut.trim();
    let newBinding = Object.assign({ handler: callback }, opts);
    this.bindKey(shortcut, newBinding);
    if (opts.help) {
      addExtraKeyboardShortcutHelp(opts.help);
    }
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
      getOwner(this).lookup("controller:topic").send("toggleBookmark");
    }
  },

  logout() {
    getOwner(this).lookup("route:application").send("logout");
  },

  quoteReply() {
    if (this.isPostTextSelected) {
      this.appEvents.trigger("quote-button:quote");
      return false;
    }

    this.sendToSelectedPost("replyToPost");
    // lazy but should work for now
    discourseLater(
      () => document.querySelector(".d-editor .quote")?.click(),
      500
    );

    return false;
  },

  editPost() {
    if (this.siteSettings.enable_fast_edit && this.isPostTextSelected) {
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
    const el = document.querySelector("#suggested-topics a.raw-topic-link");
    if (el) {
      el.click();
    } else {
      const controller = getOwner(this).lookup("controller:topic");
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
    if (document.querySelector(".container.posts")) {
      getOwner(this).lookup("controller:topic").send(direction);
    }
  },

  replyToTopic() {
    this._replyToPost();

    return false;
  },

  selectDown() {
    this._moveSelection({ direction: 1, scrollWithinPosts: true });
  },

  selectUp() {
    this._moveSelection({ direction: -1, scrollWithinPosts: true });
  },

  bulkSelectItem() {
    const elem = document.querySelector(
      ".selected input.bulk-select, .selected .select-post"
    );
    elem?.click();
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
      if (document.querySelector(".container.posts")) {
        event.preventDefault(); // We need to stop printing the current page in Firefox
        getOwner(this).lookup("controller:topic").print();
      }
    });
  },

  createTopic(event) {
    if (!(this.currentUser && this.currentUser.can_create_topic)) {
      return;
    }

    event.preventDefault();

    // If the page has a create-topic button, use it for context sensitive attributes like category
    const createTopicButton = document.querySelector("#create-topic");
    if (createTopicButton) {
      createTopicButton.click();
      return;
    }

    getOwner(this).lookup("service:composer").open({
      action: Composer.CREATE_TOPIC,
      draftKey: Composer.NEW_TOPIC_KEY,
    });
  },

  focusComposer(event) {
    const composer = getOwner(this).lookup("service:composer");
    if (event) {
      event.preventDefault();
      event.stopPropagation();
    }
    composer.focusComposer(event);
  },

  filterSidebar() {
    const filterInput = document.querySelector(".sidebar-filter__input");

    if (filterInput) {
      this._scrollTo(0);
      filterInput.focus();
    }
  },

  fullscreenComposer() {
    const composer = getOwner(this).lookup("service:composer");
    if (composer.get("model")) {
      composer.toggleFullscreen();
    }
  },

  pinUnpinTopic() {
    getOwner(this).lookup("controller:topic").togglePinnedState();
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
    getOwner(this)
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
      const registry = getOwner(this).lookup("-view-registry:main");
      if (registry) {
        const view = registry[elem.id];
        view.send(action);
      }
    }
  },

  currentTopic() {
    const topicController = getOwner(this).lookup("controller:topic");
    if (topicController) {
      const topic = topicController.get("model");
      if (topic) {
        return topic;
      }
    }
  },

  get isPostTextSelected() {
    const topicController = getOwner(this).lookup("controller:topic");
    return !!topicController.quoteState.postId;
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
      const topicController = getOwner(this).lookup("controller:topic");
      const post = topicController
        .get("model.postStream.posts")
        .findBy("id", selectedPostId);
      if (post) {
        // TODO: Use ember closure actions

        let actionMethod = topicController.actions[action];
        if (!actionMethod) {
          const topicRoute = getOwner(this).lookup("route:topic");
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

  _moveSelection({ direction, scrollWithinPosts }) {
    // Pressing a move key (J/K) very quick (i.e. keeping J or K pressed) will
    // move fast by disabling smooth page scrolling.
    const now = +new Date();
    const fast =
      this._lastMoveTime && now - this._lastMoveTime < 1.5 * animationDuration;
    this._lastMoveTime = now;

    let articles = this._findArticles();
    if (articles === undefined) {
      return;
    }
    articles = Array.from(articles);

    let selected = articles.find((element) =>
      element.classList.contains("selected")
    );
    if (!selected) {
      selected = articles.find(
        (element) => element.dataset.isLastViewedTopic === "true"
      );
    }

    // Discard selection if it is not in viewport, so users can combine
    // keyboard shortcuts with mouse scrolling.
    if (selected && !fast) {
      const rect = selected.getBoundingClientRect();
      if (rect.bottom < headerOffset() || rect.top > window.innerHeight) {
        selected = null;
      }
    }

    // If still nothing is selected, select the first post that is
    // visible and cancel move operation.
    if (!selected) {
      const offset = headerOffset();
      selected = articles.find((article) =>
        direction > 0
          ? article.getBoundingClientRect().top >= offset
          : article.getBoundingClientRect().bottom >= offset
      );
      if (!selected) {
        selected = articles[articles.length - 1];
      }
      direction = 0;
    }

    const index = articles.indexOf(selected);
    let article = selected;

    // Try doing a page scroll in the context of current post.
    if (!fast && direction !== 0 && article && scrollWithinPosts) {
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
    if (!selected) {
      if (direction === -1 && index === 0) {
        return;
      }
      if (direction === 1 && index === articles.length - 1) {
        return;
      }
    }

    let newIndex = index;
    while (true) {
      newIndex += direction;
      article = articles[newIndex];

      // Element doesn't exist
      if (!article) {
        return;
      }

      // Element is visible
      if (article.getBoundingClientRect().height > 0) {
        break;
      }
    }

    for (const a of articles) {
      a.classList.remove("selected");
      a.removeAttribute("tabindex");
    }
    article.classList.add("selected");
    article.setAttribute("tabindex", "0");
    article.focus();

    this.appEvents.trigger("keyboard:move-selection", {
      articles,
      selectedArticle: article,
    });

    const articleTop = domUtils.offset(article).top,
      articleTopPosition = articleTop - headerOffset();
    if (
      scrollWithinPosts &&
      !fast &&
      direction < 0 &&
      article.offsetHeight > window.innerHeight
    ) {
      // Scrolling to the last "page" of the previous post if post has multiple
      // "pages" (if its height does not fit in the screen).
      return this._scrollTo(
        articleTop + article.offsetHeight - window.innerHeight
      );
    } else if (article.classList.contains("topic-post")) {
      return this._scrollTo(
        article.querySelector("#post_1") ? 0 : articleTopPosition
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

  _scrollTo(scrollTop) {
    window.scrollTo({
      top: scrollTop,
      behavior: "smooth",
    });
  },

  categoriesTopicsList() {
    switch (this.siteSettings.desktop_category_page_style) {
      case "categories_with_featured_topics":
        return document.querySelectorAll(".latest .featured-topic");
      case "categories_and_latest_topics":
      case "categories_and_latest_topics_created_date":
        return document.querySelectorAll(
          ".latest-topic-list .latest-topic-list-item"
        );
      case "categories_and_top_topics":
        return document.querySelectorAll(
          ".top-topic-list .latest-topic-list-item"
        );
      default:
        return [];
    }
  },

  _findArticles() {
    let categoriesTopicsList;
    if (document.querySelector(".posts-wrapper")) {
      return document.querySelectorAll(
        ".posts-wrapper .topic-post, .topic-list tbody tr"
      );
    } else if (document.querySelector(".topic-list")) {
      return document.querySelectorAll(".topic-list .topic-list-item");
    } else if (document.querySelector(".search-results")) {
      return document.querySelectorAll(".search-results .fps-result");
    } else if ((categoriesTopicsList = this.categoriesTopicsList())) {
      return categoriesTopicsList;
    }
  },

  _changeSection(direction) {
    if (document.querySelector(".post-stream")) {
      this._moveSelection({ direction, scrollWithinPosts: false });
    } else {
      const sections = Array.from(
        document.querySelectorAll(".nav.nav-pills li")
      );
      const active = document.querySelector(".nav.nav-pills li.active");
      const index = sections.indexOf(active) + direction;

      if (index >= 0 && index < sections.length) {
        sections[index].querySelector("a, button")?.click();
      }
    }
  },

  _stopCallback() {
    const prototype = Object.getPrototypeOf(this.keyTrapper);
    const oldCallback = (this.oldStopCallback = prototype.stopCallback);

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

      return oldCallback.call(this, e, element, combo, sequence);
    };
  },

  _replyToPost() {
    getOwner(this).lookup("controller:topic").send("replyToPost");
  },

  _getSelectedPost() {
    return document.querySelector(".topic-post.selected article[data-post-id]");
  },

  _getSelectedTopicListItem() {
    return document.querySelector("tr.selected.topic-list-item");
  },

  deferTopic() {
    getOwner(this).lookup("controller:topic").send("deferTopic");
  },

  toggleAdminActions() {
    document.querySelector(".toggle-admin-menu")?.click();
  },

  toggleBulkSelect() {
    const bulkSelect = document.querySelector("button.bulk-select");

    if (bulkSelect) {
      bulkSelect.click();
    } else {
      getOwner(this).lookup("controller:topic").send("toggleMultiSelect");
    }
  },

  toggleArchivePM() {
    getOwner(this).lookup("controller:topic").send("toggleArchiveMessage");
  },

  webviewKeyboardBack() {
    if (capabilities.isAppWebview) {
      window.history.back();
    }
  },

  webviewKeyboardForward() {
    if (capabilities.isAppWebview) {
      window.history.forward();
    }
  },
};
