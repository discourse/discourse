import { alias, match } from "@ember/object/computed";
import { throttle } from "@ember/runloop";
import { next } from "@ember/runloop";
import { schedule } from "@ember/runloop";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import afterTransition from "discourse/lib/after-transition";
import DiscourseURL from "discourse/lib/url";
import Mixin from "@ember/object/mixin";

export default Mixin.create({
  elementId: null, //click detection added for data-{elementId}
  triggeringLinkClass: null, //the <a> classname where this card should appear
  _showCallback: null, //username, $target - load up data for when show is called, should call this._positionCard($target) when it's done.

  postStream: alias("topic.postStream"),
  viewingTopic: match("currentPath", /^topic\./),

  visible: false,
  username: null,
  loading: null,
  cardTarget: null,
  post: null,
  isFixed: false,
  isDocked: false,

  _show(username, $target) {
    // No user card for anon
    if (this.siteSettings.hide_user_profiles_from_public && !this.currentUser) {
      return false;
    }

    username = Ember.Handlebars.Utils.escapeExpression(username.toString());

    // Don't show if nested
    if ($target.parents(".card-content").length) {
      this._close();
      DiscourseURL.routeTo($target.attr("href"));
      return false;
    }

    const currentUsername = this.username;
    if (username === currentUsername && this.loading === username) {
      return;
    }

    const postId = $target.parents("article").data("post-id");
    const wasVisible = this.visible;
    const previousTarget = this.cardTarget;
    const target = $target[0];

    if (wasVisible) {
      this._close();
      if (target === previousTarget) {
        return;
      }
    }

    const post =
      this.viewingTopic && postId
        ? this.postStream.findLoadedPost(postId)
        : null;
    this.setProperties({
      username,
      loading: username,
      cardTarget: target,
      post
    });

    this._showCallback(username, $target);

    // We bind scrolling on mobile after cards are shown to hide them if user scrolls
    if (this.site.mobileView) {
      this._bindMobileScroll();
    }

    return false;
  },

  didInsertElement() {
    this._super(...arguments);
    afterTransition($(this.element), this._hide.bind(this));
    const id = this.elementId;
    const triggeringLinkClass = this.triggeringLinkClass;
    const clickOutsideEventName = `mousedown.outside-${id}`;
    const clickDataExpand = `click.discourse-${id}`;
    const clickMention = `click.discourse-${id}-${triggeringLinkClass}`;
    const previewClickEvent = `click.discourse-preview-${id}-${triggeringLinkClass}`;
    const mobileScrollEvent = "scroll.mobile-card-cloak";

    this.setProperties({
      clickOutsideEventName,
      clickDataExpand,
      clickMention,
      previewClickEvent,
      mobileScrollEvent
    });

    $("html")
      .off(clickOutsideEventName)
      .on(clickOutsideEventName, e => {
        if (this.visible) {
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

    this.appEvents.on(previewClickEvent, this, "_previewClick");

    this.appEvents.on(
      `topic-header:trigger-${id}`,
      this,
      "_topicHeaderTrigger"
    );
  },

  _topicHeaderTrigger(username, $target) {
    this.setProperties({ isFixed: true, isDocked: true });
    return this._show(username, $target);
  },

  _bindMobileScroll() {
    const mobileScrollEvent = this.mobileScrollEvent;
    const onScroll = () => {
      throttle(this, this._close, 1000);
    };

    $(window).on(mobileScrollEvent, onScroll);
  },

  _unbindMobileScroll() {
    const mobileScrollEvent = this.mobileScrollEvent;

    $(window).off(mobileScrollEvent);
  },

  _previewClick($target) {
    this.set("isFixed", true);
    return this._show($target.text().replace(/^@/, ""), $target);
  },

  _positionCard(target) {
    const rtl = $("html").css("direction") === "rtl";
    if (!target) {
      return;
    }
    const width = $(this.element).width();
    const height = 175;
    const isFixed = this.isFixed;
    const isDocked = this.isDocked;

    let verticalAdjustments = 0;

    schedule("afterRender", () => {
      if (target) {
        if (!this.site.mobileView) {
          let position = target.offset();
          if (target.parents(".d-header").length > 0) {
            position.top = target.position().top;
          }

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

            const avatarOverflowSize = 44;
            if (isDocked && position.top < avatarOverflowSize) {
              position.top = avatarOverflowSize;
            }

            $(this.element).css(position);
          }
        }

        if (this.site.mobileView) {
          $(".card-cloak").removeClass("hidden");
          let position = target.offset();
          position.top = "10%"; // match modal behaviour
          position.left = 0;
          $(this.element).css(position);
        }
        $(this.element).toggleClass("docked-card", isDocked);

        // After the card is shown, focus on the first link
        //
        // note: we DO NOT use afterRender here cause _positionCard may
        // run afterwards, if we allowed this to happen the usercard
        // may be offscreen and we may scroll all the way to it on focus
        next(null, () => {
          const firstLink = this.element.querySelector("a");
          firstLink && firstLink.focus();
        });
      }
    });
  },

  _hide() {
    if (!this.visible) {
      $(this.element).css({ left: -9999, top: -9999 });
      if (this.site.mobileView) {
        $(".card-cloak").addClass("hidden");
      }
    }
  },

  _close() {
    this.setProperties({
      visible: false,
      username: null,
      loading: null,
      cardTarget: null,
      post: null,
      isFixed: false,
      isDocked: false
    });

    // Card will be removed, so we unbind mobile scrolling
    if (this.site.mobileView) {
      this._unbindMobileScroll();
    }
  },

  willDestroyElement() {
    this._super(...arguments);
    const clickOutsideEventName = this.clickOutsideEventName;
    const clickDataExpand = this.clickDataExpand;
    const clickMention = this.clickMention;
    const previewClickEvent = this.previewClickEvent;

    $("html").off(clickOutsideEventName);
    $("#main")
      .off(clickDataExpand)
      .off(clickMention);

    this.appEvents.off(previewClickEvent, this, "_previewClick");

    this.appEvents.off(
      `topic-header:trigger-${this.elementId}`,
      this,
      "_topicHeaderTrigger"
    );
  },

  keyUp(e) {
    if (e.keyCode === 27) {
      // ESC
      const target = this.cardTarget;
      this._close();
      target.focus();
    }
  }
});
