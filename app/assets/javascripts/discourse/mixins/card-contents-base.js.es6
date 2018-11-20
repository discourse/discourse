import { wantsNewWindow } from "discourse/lib/intercept-click";
import afterTransition from "discourse/lib/after-transition";
import DiscourseURL from "discourse/lib/url";

export default Ember.Mixin.create({
  elementId: null, //click detection added for data-{elementId}
  triggeringLinkClass: null, //the <a> classname where this card should appear
  _showCallback: null, //username, $target - load up data for when show is called, should call this._positionCard($target) when it's done.

  postStream: Ember.computed.alias("topic.postStream"),
  viewingTopic: Ember.computed.match("currentPath", /^topic\./),

  visible: false,
  username: null,
  loading: null,
  cardTarget: null,
  post: null,
  isFixed: false,

  _show(username, $target) {
    // No user card for anon
    if (this.siteSettings.hide_user_profiles_from_public && !this.currentUser) {
      return false;
    }

    username = Ember.Handlebars.Utils.escapeExpression(username.toString());

    // Don't show on mobile
    if (this.site.mobileView) {
      DiscourseURL.routeTo($target.attr("href"));
      return false;
    }

    const currentUsername = this.get("username");
    if (username === currentUsername && this.get("loading") === username) {
      return;
    }

    const postId = $target.parents("article").data("post-id");
    const wasVisible = this.get("visible");
    const previousTarget = this.get("cardTarget");
    const target = $target[0];

    if (wasVisible) {
      this._close();
      if (target === previousTarget) {
        return;
      }
    }

    const post =
      this.get("viewingTopic") && postId
        ? this.get("postStream").findLoadedPost(postId)
        : null;
    this.setProperties({
      username,
      loading: username,
      cardTarget: target,
      post
    });

    this._showCallback(username, $target);

    return false;
  },

  didInsertElement() {
    this._super();
    afterTransition(this.$(), this._hide.bind(this));
    const id = this.get("elementId");
    const triggeringLinkClass = this.get("triggeringLinkClass");
    const clickOutsideEventName = `mousedown.outside-${id}`;
    const clickDataExpand = `click.discourse-${id}`;
    const clickMention = `click.discourse-${id}-${triggeringLinkClass}`;
    const previewClickEvent = `click.discourse-preview-${id}-${triggeringLinkClass}`;

    this.setProperties({
      clickOutsideEventName,
      clickDataExpand,
      clickMention,
      previewClickEvent
    });

    $("html")
      .off(clickOutsideEventName)
      .on(clickOutsideEventName, e => {
        if (this.get("visible")) {
          const $target = $(e.target);
          if (
            $target.closest(`[data-${id}]`).data(id) ||
            $target.closest(`a.${triggeringLinkClass}`).length > 0 ||
            $target.closest(`#${id}`).length > 0
          ) {
            return;
          }

          this._close();
        }

        return true;
      });

    $("#main-outlet").on(clickDataExpand, `[data-${id}]`, e => {
      if (wantsNewWindow(e)) {
        return;
      }
      const $target = $(e.currentTarget);
      return this._show($target.data(id), $target);
    });

    $("#main-outlet").on(clickMention, `a.${triggeringLinkClass}`, e => {
      if (wantsNewWindow(e)) {
        return;
      }
      const $target = $(e.target);
      return this._show($target.text().replace(/^@/, ""), $target);
    });

    this.appEvents.on(previewClickEvent, $target => {
      this.set("isFixed", true);
      return this._show($target.text().replace(/^@/, ""), $target);
    });
  },

  _positionCard(target) {
    const rtl = $("html").css("direction") === "rtl";
    if (!target) {
      return;
    }
    const width = this.$().width();
    const height = 175;
    const isFixed = this.get("isFixed");

    let verticalAdjustments = 0;

    Ember.run.schedule("afterRender", () => {
      if (target) {
        let position = target.offset();
        if (position) {
          position.bottom = "unset";

          if (rtl) {
            // The site direction is rtl
            position.right = $(window).width() - position.left + 10;
            position.left = "auto";
            let overage = $(window).width() - 50 - (position.right + width);
            if (overage < 0) {
              position.right += overage;
              position.top += target.height() + 48;
              verticalAdjustments += target.height() + 48;
            }
          } else {
            // The site direction is ltr
            position.left += target.width() + 10;

            let overage = $(window).width() - 50 - (position.left + width);
            if (overage < 0) {
              position.left += overage;
              position.top += target.height() + 48;
              verticalAdjustments += target.height() + 48;
            }
          }

          position.top -= $("#main-outlet").offset().top;
          if (isFixed) {
            position.top -= $("html").scrollTop();
            //if content is fixed and will be cut off on the bottom, display it above...
            if (
              position.top + height + verticalAdjustments >
              $(window).height() - 50
            ) {
              position.bottom =
                $(window).height() -
                (target.offset().top - $("html").scrollTop());
              if (verticalAdjustments > 0) {
                position.bottom += 48;
              }
              position.top = "unset";
            }
          }
          this.$().css(position);
        }

        // After the card is shown, focus on the first link
        //
        // note: we DO NOT use afterRender here cause _positionCard may
        // run afterwards, if we allowed this to happen the usercard
        // may be offscreen and we may scroll all the way to it on focus
        Ember.run.next(null, () => this.$("a:first").focus());
      }
    });
  },

  _hide() {
    if (!this.get("visible")) {
      this.$().css({ left: -9999, top: -9999 });
    }
  },

  _close() {
    this.setProperties({
      visible: false,
      username: null,
      loading: null,
      cardTarget: null,
      post: null,
      isFixed: false
    });
  },

  willDestroyElement() {
    this._super();
    const clickOutsideEventName = this.get("clickOutsideEventName");
    const clickDataExpand = this.get("clickDataExpand");
    const clickMention = this.get("clickMention");
    const previewClickEvent = this.get("previewClickEvent");
    $("html").off(clickOutsideEventName);
    $("#main")
      .off(clickDataExpand)
      .off(clickMention);
    this.appEvents.off(previewClickEvent);
  },

  keyUp(e) {
    if (e.keyCode === 27) {
      // ESC
      const target = this.get("cardTarget");
      this._close();
      target.focus();
    }
  }
});
