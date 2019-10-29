import Component from "@ember/component";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { longDateNoYear } from "discourse/lib/formatter";
import {
  default as computed,
  on
} from "ember-addons/ember-computed-decorators";
import Sharing from "discourse/lib/sharing";
import { nativeShare } from "discourse/lib/pwa-utils";

export default Component.extend({
  elementId: "share-link",
  classNameBindings: ["visible"],
  link: null,
  visible: null,

  @computed
  sources() {
    return Sharing.activeSources(this.siteSettings.share_links);
  },

  @computed("type", "postNumber")
  shareTitle(type, postNumber) {
    if (type === "topic") {
      return I18n.t("share.topic");
    }
    if (postNumber) {
      return I18n.t("share.post", { postNumber });
    }
    return I18n.t("share.topic");
  },

  @computed("date")
  displayDate(date) {
    return longDateNoYear(new Date(date));
  },

  _focusUrl() {
    const link = this.link;
    if (!this.capabilities.touch) {
      const $linkInput = $("#share-link input");
      $linkInput.val(link);

      // Wait for the fade-in transition to finish before selecting the link:
      window.setTimeout(() => $linkInput.select().focus(), 160);
    } else {
      const $linkForTouch = $("#share-link .share-for-touch a");
      $linkForTouch.attr("href", link);
      $linkForTouch.text(link);
      const range = window.document.createRange();
      range.selectNode($linkForTouch[0]);
      window.getSelection().addRange(range);
    }
  },

  _showUrl($target, url) {
    const $currentTargetOffset = $target.offset();
    const $this = $(this.element);

    if (Ember.isEmpty(url)) {
      return;
    }

    // Relative urls
    if (url.indexOf("/") === 0) {
      url = window.location.protocol + "//" + window.location.host + url;
    }

    const shareLinkWidth = $this.width();
    let x = $currentTargetOffset.left - shareLinkWidth / 2;
    if (x < 25) {
      x = 25;
    }
    if (x + shareLinkWidth > $(window).width()) {
      x -= shareLinkWidth / 2;
    }

    const header = $(".d-header");
    let y = $currentTargetOffset.top - ($this.height() + 20);
    if (y < header.offset().top + header.height()) {
      y = $currentTargetOffset.top + 10;
    }

    $this.css({ top: "" + y + "px" });

    if (!this.site.mobileView) {
      $this.css({ left: "" + x + "px" });
    }
    this.set("link", url);
    this.set("visible", true);

    Ember.run.scheduleOnce("afterRender", this, this._focusUrl);
  },

  _mouseDownHandler(event) {
    if (!this.element || this.isDestroying || this.isDestroyed) {
      return;
    }

    // Use mousedown instead of click so this event is handled before routing occurs when a
    // link is clicked (which is a click event) while the share dialog is showing.
    if ($(this.element).has(event.target).length !== 0) {
      return;
    }

    this.send("close");

    return true;
  },

  _clickHandler(event) {
    if (!this.element || this.isDestroying || this.isDestroyed) {
      return;
    }

    // if they want to open in a new tab, let it so
    if (wantsNewWindow(event)) {
      return true;
    }

    event.preventDefault();

    const $currentTarget = $(event.currentTarget);
    const url = $currentTarget.data("share-url");
    const postNumber = $currentTarget.data("post-number");
    const postId = $currentTarget.closest("article").data("post-id");
    const date = $currentTarget.children().data("time");

    this.setProperties({ postNumber, date, postId });

    // use native webshare only when the user clicks on the "chain" icon
    if (!$currentTarget.hasClass("post-date")) {
      nativeShare({ url }).then(null, () => this._showUrl($currentTarget, url));
    } else {
      this._showUrl($currentTarget, url);
    }

    return false;
  },

  _keydownHandler(event) {
    if (!this.element || this.isDestroying || this.isDestroyed) {
      return;
    }

    if (event.keyCode === 27) {
      this.send("close");
    }
  },

  _shareUrlHandler(url, $target) {
    this._showUrl($target, url);
  },

  @on("init")
  _setupHandlers() {
    this._boundMouseDownHandler = Ember.run.bind(this, this._mouseDownHandler);
    this._boundClickHandler = Ember.run.bind(this, this._clickHandler);
    this._boundKeydownHandler = Ember.run.bind(this, this._keydownHandler);
  },

  didInsertElement() {
    this._super(...arguments);

    $("html")
      .on("mousedown.outside-share-link", this._boundMouseDownHandler)
      .on(
        "click.discourse-share-link",
        "button[data-share-url], .post-info .post-date[data-share-url]",
        this._boundClickHandler
      )
      .on("keydown.share-view", this._boundKeydownHandler);

    this.appEvents.on("share:url", this, "_shareUrlHandler");
  },

  willDestroyElement() {
    this._super(...arguments);

    $("html")
      .off("click.discourse-share-link", this._boundClickHandler)
      .off("mousedown.outside-share-link", this._boundMouseDownHandler)
      .off("keydown.share-view", this._boundKeydownHandler);

    this.appEvents.off("share:url", this, "_shareUrlHandler");
  },

  actions: {
    replyAsNewTopic() {
      const postStream = this.get("topic.postStream");
      const postId = this.postId || postStream.findPostIdForPostNumber(1);
      const post = postStream.findLoadedPost(postId);
      this.replyAsNewTopic(post);
      this.send("close");
    },

    close() {
      this.setProperties({
        link: null,
        postNumber: null,
        postId: null,
        visible: false
      });
    },

    share(source) {
      Sharing.shareSource(source, {
        url: this.link,
        title: this.get("topic.title")
      });
    }
  }
});
