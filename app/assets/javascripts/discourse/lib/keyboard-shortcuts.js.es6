import DiscourseURL from "discourse/lib/url";
import Composer from "discourse/models/composer";
import { minimumOffset } from "discourse/lib/offset-calculator";
import { ajax } from "discourse/lib/ajax";

const bindings = {
  "!": { postAction: "showFlags" },
  "#": { handler: "goToPost", anonymous: true },
  "/": { handler: "toggleSearch", anonymous: true },
  "ctrl+alt+f": { handler: "toggleSearch", anonymous: true, global: true },
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
  "g s": { handler: "goToFirstSuggestedTopic", anonymous: true },
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
  "shift+l": { handler: "goToUnreadPost" },
  "shift+z shift+z": { handler: "logout" },
  "shift+f11": { handler: "fullscreenComposer", global: true },
  "shift+u": { handler: "deferTopic" },
  t: { postAction: "replyAsNewTopic" },
  u: { handler: "goBack", anonymous: true },
  "x r": {
    click: "#dismiss-new,#dismiss-new-top,#dismiss-posts,#dismiss-posts-top"
  }, // dismiss new/posts
  "x t": { click: "#dismiss-topics,#dismiss-topics-top" } // dismiss topics
};

const animationDuration = 100;

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

    return false;
  },

  goToFirstSuggestedTopic() {
    const $el = $(".suggested-topics a.raw-topic-link:first");
    if ($el.length) {
      $el.click();
    } else {
      const controller = this.container.lookup("controller:topic");
      // Only the last page contains list of suggested topics.
      const url = `/t/${controller.get("model.id")}/last.json`;
      ajax(url).then(result => {
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
    if (!(this.currentUser && this.currentUser.can_create_topic)) {
      return;
    }

    // If the page has a create-topic button, use it for context sensitive attributes like category
    let $createTopicButton = $("#create-topic");
    if ($createTopicButton.length) {
      $createTopicButton.click();
      return;
    }

    this.container.lookup("controller:composer").open({
      action: Composer.CREATE_TOPIC,
      draftKey: Composer.CREATE_TOPIC
    });
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

    return false;
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

  _globalBindToFunction(func, binding) {
    if (typeof this[func] === "function") {
      this.keyTrapper.bindGlobal(binding, this[func].bind(this));
    }
  },

  _bindToFunction(func, binding) {
    if (typeof this[func] === "function") {
      this.keyTrapper.bind(binding, this[func].bind(this));
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
      const offset = minimumOffset();
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
      const offset = minimumOffset();
      $selected = $articles
        .toArray()
        .find(article => article.getBoundingClientRect().top > offset);
      if (!$selected) {
        $selected = $articles[$articles.length - 1];
      }
      direction = 0;
    }

    const index = $articles.index($selected);
    let $article = $articles.eq(index);

    // Try doing a page scroll in the context of current post.
    if (!fast && direction !== 0 && $article.length > 0) {
      // The beginning of first article is the beginning of the page.
      const beginArticle =
        $article.is(".topic-post") && $article.find("#post_1").length
          ? 0
          : $article.offset().top;
      const endArticle =
        $article.offset().top + $article[0].getBoundingClientRect().height;

      const beginScreen = $(window).scrollTop();
      const endScreen = beginScreen + window.innerHeight;

      if (direction < 0 && beginScreen > beginArticle) {
        return this._scrollTo(
          Math.max(
            beginScreen - window.innerHeight + 3 * minimumOffset(), // page up
            beginArticle - minimumOffset() // beginning of article
          )
        );
      } else if (direction > 0 && endScreen < endArticle - minimumOffset()) {
        return this._scrollTo(
          Math.min(
            endScreen - 3 * minimumOffset(), // page down
            endArticle - window.innerHeight // end of article
          )
        );
      }
    }

    // Try scrolling to post above or below.
    if ($selected.length !== 0) {
      if (direction === -1 && index === 0) return;
      if (direction === 1 && index === $articles.length - 1) return;
    }

    $article = $articles.eq(index + direction);
    if ($article.length > 0) {
      $articles.removeClass("selected");
      $article.addClass("selected");

      const articleRect = $article[0].getBoundingClientRect();
      if (!fast && direction < 0 && articleRect.height > window.innerHeight) {
        // Scrolling to the last "page" of the previous post if post has multiple
        // "pages" (if its height does not fit in the screen).
        return this._scrollTo(
          $article.offset().top + articleRect.height - window.innerHeight
        );
      } else if ($article.is(".topic-post")) {
        return this._scrollTo(
          $article.find("#post_1").length > 0
            ? 0
            : $article.offset().top - minimumOffset(),
          () => $("a.tabLoc", $article).focus()
        );
      }

      // Otherwise scroll through the suggested topic list.
      this._scrollList($article, direction);
    }
  },

  _scrollTo(scrollTop, complete) {
    $("html, body")
      .stop(true, true)
      .animate({ scrollTop }, { duration: animationDuration, complete });
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
      animationDuration
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
  },

  deferTopic() {
    this.container.lookup("controller:topic").send("deferTopic");
  }
};
