import { wantsNewWindow } from "discourse/lib/intercept-click";
import { longDateNoYear } from "discourse/lib/formatter";
import computed from "ember-addons/ember-computed-decorators";
import Sharing from "discourse/lib/sharing";

export default Ember.Component.extend({
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
    const link = this.get("link");
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
    const $this = this.$();

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
    this.set("link", encodeURI(url));
    this.set("visible", true);

    Ember.run.scheduleOnce("afterRender", this, this._focusUrl);
  },

  _webShare(url) {
    // We can pass title and text too, but most share targets do their own oneboxing
    return navigator.share({ url });
  },

  didInsertElement() {
    this._super(...arguments);

    const $html = $("html");
    $html.on("mousedown.outside-share-link", e => {
      // Use mousedown instead of click so this event is handled before routing occurs when a
      // link is clicked (which is a click event) while the share dialog is showing.
      if (this.$().has(e.target).length !== 0) {
        return;
      }
      this.send("close");
      return true;
    });

    $html.on(
      "click.discourse-share-link",
      "button[data-share-url], .post-info .post-date[data-share-url]",
      e => {
        // if they want to open in a new tab, let it so
        if (wantsNewWindow(e)) {
          return true;
        }

        e.preventDefault();

        const $currentTarget = $(e.currentTarget);
        const url = $currentTarget.data("share-url");
        const postNumber = $currentTarget.data("post-number");
        const postId = $currentTarget.closest("article").data("post-id");
        const date = $currentTarget.children().data("time");

        this.setProperties({ postNumber, date, postId });

        // use native webshare only when the user clicks on the "chain" icon
        // navigator.share needs HTTPS, returns undefined on HTTP
        if (navigator.share && !$currentTarget.hasClass("post-date")) {
          this._webShare(url).catch(() => {
            // if navigator fails for unexpected reason fallback to popup
            this._showUrl($currentTarget, url);
          });
        } else {
          this._showUrl($currentTarget, url);
        }

        return false;
      }
    );

    $html.on("keydown.share-view", e => {
      if (e.keyCode === 27) {
        this.send("close");
      }
    });

    this.appEvents.on("share:url", (url, $target) =>
      this._showUrl($target, url)
    );
  },

  willDestroyElement() {
    this._super(...arguments);
    $("html")
      .off("click.discourse-share-link")
      .off("mousedown.outside-share-link")
      .off("keydown.share-view");
  },

  actions: {
    replyAsNewTopic() {
      const postStream = this.get("topic.postStream");
      const postId =
        this.get("postId") || postStream.findPostIdForPostNumber(1);
      const post = postStream.findLoadedPost(postId);
      this.get("replyAsNewTopic")(post);
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
      const url = source.generateUrl(this.get("link"), this.get("topic.title"));
      if (source.shouldOpenInPopup) {
        window.open(
          url,
          "",
          "menubar=no,toolbar=no,resizable=yes,scrollbars=yes,width=600,height=" +
            (source.popupHeight || 315)
        );
      } else {
        window.open(url, "_blank");
      }
    }
  }
});
