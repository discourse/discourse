import DiscourseURL from "discourse/lib/url";
import Composer from "discourse/models/composer";
import { minimumOffset } from "discourse/lib/offset-calculator";

const bindings = {
  "!": { postAction: "showFlags" },
  "#": { handler: "goToPost", anonymous: true },
  "/": { handler: "toggleSearch", anonymous: true },
  "ctrl+alt+f": { handler: "toggleSearch", anonymous: true },
  "=": { handler: "toggleHamburgerMenu", anonymous: true },
  "?": { handler: "showHelpModal", anonymous: true },
  ".": { click: ".alert.alert-info.clickable", anonymous: true }, // show incoming/updated topics
  b: { handler: "toggleBookmark" },
  c: { handler: "createTopic" },
  C: { handler: "focusComposer" },
  "ctrl+f": { handler: "showPageSearch", anonymous: true },
  "command+f": { handler: "showPageSearch", anonymous: true },
  "ctrl+p": { handler: "printTopic", anonymous: true },
  "command+p": { handler: "printTopic", anonymous: true },
  d: { postAction: "deletePost" },
  e: { postAction: "editPost" },
  end: { handler: "goToLastPost", anonymous: true },
  "command+down": { handler: "goToLastPost", anonymous: true },
  f: { handler: "toggleBookmarkTopic" },
  "g h": { path: "/", anonymous: true },
  "g l": { path: "/latest", anonymous: true },
  "g n": { path: "/new" },
  "g u": { path: "/unread" },
  "g c": { path: "/categories", anonymous: true },
  "g t": { path: "/top", anonymous: true },
  "g b": { path: "/bookmarks" },
  "g p": { path: "/my/activity" },
  "g m": { path: "/my/messages" },
  "g d": { path: "/my/activity/drafts" },
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
      ".latest .featured-topic.selected a.title"
    ].join(", "),
    anonymous: true
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
  "shift+u": { handler: "goToUnreadPost" },
  "shift+z shift+z": { handler: "logout" },
  "shift+f11": { handler: "fullscreenComposer" },
  t: { postAction: "replyAsNewTopic" },
  u: { handler: "goBack", anonymous: true },
  "x r": {
    click: "#dismiss-new,#dismiss-new-top,#dismiss-posts,#dismiss-posts-top"
  }, // dismiss new/posts
  "x t": { click: "#dismiss-topics,#dismiss-topics-top" } // dismiss topics
};

export default {
  bindEvents(keyTrapper, container) {
    this.keyTrapper = keyTrapper;
    this.container = container;
    this._stopCallback();

    this.searchService = this.container.lookup("search-service:main");
    this.appEvents = this.container.lookup("app-events:main");
    this.currentUser = this.container.lookup("current-user:main");
    let siteSettings = this.container.lookup("site-settings:main");

    // Disable the shortcut if private messages are disabled
    if (!siteSettings.enable_personal_messages) {
      delete bindings["g m"];
    }

    Object.keys(bindings).forEach(key => {
      const binding = bindings[key];
      if (!binding.anonymous && !this.currentUser) {
        return;
      }

      if (binding.path) {
        this._bindToPath(binding.path, key);
      } else if (binding.handler) {
        this._bindToFunction(binding.handler, key);
      } else if (binding.postAction) {
        this._bindToSelectedPost(binding.postAction, key);
      } else if (binding.click) {
        this._bindToClick(binding.click, key);
      }
    });
  },

  toggleBookmark() {
    this.sendToSelectedPost("toggleBookmark");
    this.sendToTopicListItemView("toggleBookmark");
  },

  toggleBookmarkTopic() {
    const topic = this.currentTopic();
    // BIG hack, need a cleaner way
    if (topic && $(".posts-wrapper").length > 0) {
      this.container.lookup("controller:topic").send("toggleBookmark");
    } else {
      this.sendToTopicListItemView("toggleBookmark");
    }
  },

  logout() {
    this.container.lookup("route:application").send("logout");
  },

  quoteReply() {
    this.sendToSelectedPost("replyToPost");
    // lazy but should work for now
    Ember.run.later(() => $(".d-editor .quote").click(), 500);
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
    Ember.run(() => {
      this.appEvents.trigger("header:keyboard-trigger", {
        type: "page-search",
        event
      });
    });
  },

  printTopic(event) {
    Ember.run(() => {
      if ($(".container.posts").length) {
        event.preventDefault(); // We need to stop printing the current page in Firefox
        this.container.lookup("controller:topic").print();
      }
    });
  },

  createTopic() {
    if (this.currentUser && this.currentUser.can_create_topic) {
      this.container.lookup("controller:composer").open({
        action: Composer.CREATE_TOPIC,
        draftKey: Composer.CREATE_TOPIC
      });
    }
  },

  focusComposer() {
    const composer = this.container.lookup("controller:composer");
    if (composer.get("model.viewOpen")) {
      setTimeout(() => $("textarea.d-editor-input").focus(), 0);
    } else {
      composer.send("openIfDraft");
    }
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

  goToPost() {
    this.appEvents.trigger("topic:keyboard-trigger", { type: "jump" });
  },

  toggleSearch(event) {
    this.appEvents.trigger("header:keyboard-trigger", {
      type: "search",
      event
    });

    return false;
  },

  toggleHamburgerMenu(event) {
    this.appEvents.trigger("header:keyboard-trigger", {
      type: "hamburger",
      event
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

  setTrackingToMuted(event) {
    this.appEvents.trigger("topic-notifications-button:changed", {
      type: "notification",
      id: 0,
      event
    });
  },

  setTrackingToRegular(event) {
    this.appEvents.trigger("topic-notifications-button:changed", {
      type: "notification",
      id: 1,
      event
    });
  },

  setTrackingToTracking(event) {
    this.appEvents.trigger("topic-notifications-button:changed", {
      type: "notification",
      id: 2,
      event
    });
  },

  setTrackingToWatching(event) {
    this.appEvents.trigger("topic-notifications-button:changed", {
      type: "notification",
      id: 3,
      event
    });
  },

  sendToTopicListItemView(action) {
    const elem = $("tr.selected.topic-list-item.ember-view")[0];
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

  sendToSelectedPost(action) {
    const container = this.container;
    // TODO: We should keep track of the post without a CSS class
    let selectedPostId = parseInt(
      $(".topic-post.selected article.boxed").data("post-id"),
      10
    );
    if (selectedPostId) {
      const topicController = container.lookup("controller:topic");
      const post = topicController
        .get("model.postStream.posts")
        .findBy("id", selectedPostId);
      if (post) {
        // TODO: Use ember closure actions

        let actionMethod = topicController.actions[action];
        if (!actionMethod) {
          const topicRoute = container.lookup("route:topic");
          actionMethod = topicRoute.actions[action];
        }

        const result = actionMethod.call(topicController, post);
        if (result && result.then) {
          this.appEvents.trigger("post-stream:refresh", { id: selectedPostId });
        }
      }
    }
  },

  _bindToSelectedPost(action, binding) {
    this.keyTrapper.bind(binding, () => this.sendToSelectedPost(action));
  },

  _bindToPath(path, key) {
    this.keyTrapper.bind(key, () =>
      DiscourseURL.routeTo(Discourse.BaseUri + path)
    );
  },

  _bindToClick(selector, binding) {
    binding = binding.split(",");
    this.keyTrapper.bind(binding, function(e) {
      const $sel = $(selector);

      // Special case: We're binding to enter.
      if (e && e.keyCode === 13) {
        // Binding to enter should only be effective when there is something
        // to select.
        if ($sel.length === 0) {
          return;
        }

        // If effective, prevent default.
        e.preventDefault();
      }
      $sel.click();
    });
  },

  _bindToFunction(func, binding) {
    if (typeof this[func] === "function") {
      this.keyTrapper.bind(binding, _.bind(this[func], this));
    }
  },

  _moveSelection(direction) {
    const $articles = this._findArticles();

    if (typeof $articles === "undefined") return;

    const $selected =
      $articles.filter(".selected").length !== 0
        ? $articles.filter(".selected")
        : $articles.filter("[data-islastviewedtopic=true]");

    let index = $articles.index($selected);

    if ($selected.length !== 0) {
      if (direction === -1 && index === 0) return;
      if (direction === 1 && index === $articles.length - 1) return;
    }

    // when nothing is selected
    if ($selected.length === 0) {
      // select the first post with its top visible
      const offset = minimumOffset();
      index = $articles
        .toArray()
        .findIndex(article => article.getBoundingClientRect().top > offset);
      direction = 0;
    }

    const $article = $articles.eq(index + direction);

    if ($article.length > 0) {
      $articles.removeClass("selected");
      $article.addClass("selected");

      if ($article.is(".topic-post")) {
        $("a.tabLoc", $article).focus();
        this._scrollToPost($article);
      } else {
        this._scrollList($article, direction);
      }
    }
  },

  _scrollToPost($article) {
    if ($article.find("#post_1").length > 0) {
      $(window).scrollTop(0);
    } else {
      $(window).scrollTop($article.offset().top - minimumOffset());
    }
  },

  _scrollList($article) {
    // Try to keep the article on screen
    const pos = $article.offset();
    const height = $article.height();
    const headerHeight = $("header.d-header").height();
    const scrollTop = $(window).scrollTop();
    const windowHeight = $(window).height();

    // skip if completely on screen
    if (
      pos.top - headerHeight > scrollTop &&
      pos.top + height < scrollTop + windowHeight
    ) {
      return;
    }

    let scrollPos = pos.top + height / 2 - windowHeight * 0.5;
    if (height > windowHeight - headerHeight) {
      scrollPos = pos.top - headerHeight;
    }
    if (scrollPos < 0) {
      scrollPos = 0;
    }

    if (this._scrollAnimation) {
      this._scrollAnimation.stop();
    }
    this._scrollAnimation = $("html, body").animate(
      { scrollTop: scrollPos + "px" },
      100
    );
  },

  categoriesTopicsList() {
    const setting = this.container.lookup("site-settings:main")
      .desktop_category_page_style;
    switch (setting) {
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

    if ($postsWrapper.length > 0) {
      return $(".posts-wrapper .topic-post, .topic-list tbody tr");
    } else if ($topicList.length > 0) {
      return $topicList.find(".topic-list-item");
    } else if ($categoriesTopicsList.length > 0) {
      return $categoriesTopicsList;
    }
  },

  _changeSection(direction) {
    const $sections = $(".nav.nav-pills li"),
      active = $(".nav.nav-pills li.active"),
      index = $sections.index(active) + direction;

    if (index >= 0 && index < $sections.length) {
      $sections
        .eq(index)
        .find("a")
        .click();
    }
  },

  _stopCallback() {
    const oldStopCallback = this.keyTrapper.prototype.stopCallback;

    this.keyTrapper.prototype.stopCallback = function(
      e,
      element,
      combo,
      sequence
    ) {
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
  }
};
