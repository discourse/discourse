import { alias, match } from "@ember/object/computed";
import { schedule, throttle } from "@ember/runloop";
import DiscourseURL from "discourse/lib/url";
import Mixin from "@ember/object/mixin";
import { escapeExpression } from "discourse/lib/utilities";
import { inject as service } from "@ember/service";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { bind } from "discourse-common/utils/decorators";
import discourseLater from "discourse-common/lib/later";
import { headerOffset } from "discourse/lib/offset-calculator";

const DEFAULT_SELECTOR = "#main-outlet";

let _cardClickListenerSelectors = [DEFAULT_SELECTOR];

export function addCardClickListenerSelector(selector) {
  _cardClickListenerSelectors.push(selector);
}

export function resetCardClickListenerSelector() {
  _cardClickListenerSelectors = [DEFAULT_SELECTOR];
}

export default Mixin.create({
  router: service(),
  menu: service(),

  elementId: null, //click detection added for data-{elementId}
  triggeringLinkClass: null, //the <a> classname where this card should appear
  _showCallback: null, //username, $target - load up data for when show is called, should call this._positionCard($target) when it's done.

  postStream: alias("topic.postStream"),
  viewingTopic: match("router.currentRouteName", /^topic\./),

  visible: false,
  username: null,
  loading: null,
  cardTarget: null,
  post: null,
  isDocked: false,

  _menuInstance: null,

  _show(username, target, event) {
    // No user card for anon
    if (this.siteSettings.hide_user_profiles_from_public && !this.currentUser) {
      return false;
    }

    username = escapeExpression(username.toString());

    // Don't show if nested
    if (target.closest(".card-content")) {
      this._close();
      DiscourseURL.routeTo(target.href);
      return false;
    }

    this.appEvents.trigger("card:show", username, target, event);

    const closestArticle = target.closest("article");
    const postId = closestArticle?.dataset?.postId || null;
    const wasVisible = this.visible;
    const previousTarget = this.cardTarget;

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
      post,
    });

    document.querySelector(".card-cloak")?.classList.remove("hidden");
    this.appEvents.trigger("user-card:show", { username });
    this._showCallback(username, $(target)).then((user) => {
      this.appEvents.trigger("user-card:after-show", { user });
    });

    // We bind scrolling on mobile after cards are shown to hide them if user scrolls
    if (this.site.mobileView) {
      this._bindMobileScroll();
    }

    return false;
  },

  didInsertElement() {
    this._super(...arguments);

    const id = this.elementId;
    const triggeringLinkClass = this.triggeringLinkClass;
    const previewClickEvent = `click.discourse-preview-${id}-${triggeringLinkClass}`;
    const mobileScrollEvent = "scroll.mobile-card-cloak";

    this.setProperties({
      boundCardClickHandler: this._cardClickHandler,
      previewClickEvent,
      mobileScrollEvent,
    });

    document.addEventListener("mousedown", this._clickOutsideHandler);
    document.addEventListener("keyup", this._escListener);

    _cardClickListenerSelectors.forEach((selector) => {
      document
        .querySelector(selector)
        .addEventListener("click", this.boundCardClickHandler);
    });

    this.appEvents.on(previewClickEvent, this, "_previewClick");

    this.appEvents.on(
      `topic-header:trigger-${id}`,
      this,
      "_topicHeaderTrigger"
    );

    this.appEvents.on("card:close", this, "_close");
  },

  @bind
  _cardClickHandler(event) {
    if (this.avatarSelector) {
      let matched = this._showCardOnClick(
        event,
        this.avatarSelector,
        (el) => el.dataset[this.avatarDataAttrKey]
      );

      if (matched) {
        return; // Don't need to check for mention click; it's an avatar click
      }
    }

    // Mention click
    this._showCardOnClick(event, this.mentionSelector, (el) =>
      el.innerText.replace(/^@/, "")
    );
  },

  _showCardOnClick(event, selector, transformText) {
    let matchingEl = event.target.closest(selector);
    if (matchingEl) {
      if (wantsNewWindow(event)) {
        return true;
      }

      event.preventDefault();
      event.stopPropagation();
      return this._show(transformText(matchingEl), matchingEl, event);
    }

    return false;
  },

  _topicHeaderTrigger(username, target) {
    this.setProperties({ isDocked: true });
    return this._show(username, target);
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
    return this._show($target.text().replace(/^@/, ""), $target);
  },

  _positionCard(target) {
    schedule("afterRender", async () => {
      if (!target) {
        return;
      }

      const avatarOverflowSize = 44;
      if (this.site.desktopView) {
        this._menuInstance = await this.menu.show(target[0], {
          content: this.element,
          autoUpdate: false,
          identifier: "card",
          padding: {
            top: 10 + avatarOverflowSize + headerOffset(),
            right: 10,
            bottom: 10,
            left: 10,
          },
        });
      } else {
        this._menuInstance = await this.menu.show(target[0], {
          content: this.element,
          strategy: "fixed",
          identifier: "card",
          computePosition: (content) => {
            content.style.left = "10px";
            content.style.right = "10px";
            content.style.top = 10 + avatarOverflowSize + "px";
          },
        });
      }

      this.element.classList.toggle("docked-card", this.isDocked);

      // After the card is shown, focus on the first link
      //
      // note: we DO NOT use afterRender here cause _positionCard may
      // run afterwards, if we allowed this to happen the usercard
      // may be offscreen and we may scroll all the way to it on focus
      if (event?.pointerId === -1) {
        discourseLater(() => {
          this.element.querySelector("a")?.focus();
        }, 350);
      }
    });
  },

  @bind
  _hide() {
    if (!this.visible) {
      if (this.site.mobileView) {
        $(".card-cloak").addClass("hidden");
      }
    }

    this._menuInstance?.destroy();
  },

  _close() {
    this.setProperties({
      visible: false,
      username: null,
      loading: null,
      cardTarget: null,
      post: null,
      isDocked: false,
    });

    // Card will be removed, so we unbind mobile scrolling
    if (this.site.mobileView) {
      this._unbindMobileScroll();
    }

    this._hide();
    this.appEvents.trigger("card:hide");
  },

  willDestroyElement() {
    this._super(...arguments);

    document.removeEventListener("mousedown", this._clickOutsideHandler);
    document.removeEventListener("keyup", this._escListener);

    _cardClickListenerSelectors.forEach((selector) => {
      document
        .querySelector(selector)
        .removeEventListener("click", this.boundCardClickHandler);
    });

    const previewClickEvent = this.previewClickEvent;
    this.appEvents.off(previewClickEvent, this, "_previewClick");

    this.appEvents.off(
      `topic-header:trigger-${this.elementId}`,
      this,
      "_topicHeaderTrigger"
    );

    this.appEvents.off("card:close", this, "_close");
    this._hide();
  },

  @bind
  _clickOutsideHandler(event) {
    if (this.visible) {
      if (
        event.target
          .closest(`[data-${this.elementId}]`)
          ?.getAttribute(`data-${this.elementId}`) ||
        event.target.closest(`a.${this.triggeringLinkClass}`) ||
        event.target.closest(`#${this.elementId}`)
      ) {
        return;
      }

      this._close();
    }

    return true;
  },

  @bind
  _escListener(event) {
    if (this.visible && event.key === "Escape") {
      this.cardTarget?.focus();
      this._close();
      return;
    }
  },
});
