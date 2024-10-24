import Component from "@ember/component";
import { alias, match } from "@ember/object/computed";
import { next, schedule, throttle } from "@ember/runloop";
import { service } from "@ember/service";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { headerOffset } from "discourse/lib/offset-calculator";
import DiscourseURL from "discourse/lib/url";
import { escapeExpression } from "discourse/lib/utilities";
import discourseLater from "discourse-common/lib/later";
import { bind } from "discourse-common/utils/decorators";

const DEFAULT_SELECTOR = "#main-outlet";
const AVATAR_OVERFLOW_SIZE = 44;
const MOBILE_SCROLL_EVENT = "scroll.mobile-card-cloak";

let _cardClickListenerSelectors = [DEFAULT_SELECTOR];

export function addCardClickListenerSelector(selector) {
  _cardClickListenerSelectors.push(selector);
}

export function resetCardClickListenerSelector() {
  _cardClickListenerSelectors = [DEFAULT_SELECTOR];
}

export default class CardContentsBase extends Component {
  @service appEvents;
  @service currentUser;
  @service menu;
  @service router;
  @service site;
  @service siteSettings;

  elementId = null; //click detection added for data-{elementId}

  visible = false;
  username = null;
  loading = null;
  cardTarget = null;
  post = null;
  isDocked = false;

  @alias("topic.postStream") postStream;
  @match("router.currentRouteName", /^topic\./) viewingTopic;

  _menuInstance = null;

  _show(username, target, event) {
    // No user card for anon
    if (this.siteSettings.hide_user_profiles_from_public && !this.currentUser) {
      return true;
    }

    username = escapeExpression(username.toString());

    // Don't show if nested
    if (target.closest(".card-content")) {
      this._close();
      DiscourseURL.routeTo(target.href);
      return false;
    }

    this.appEvents.trigger("card:show", username, target, event);

    const postId = target.closest("article")?.dataset?.postId || null;

    if (this.visible) {
      this._close();
      if (target === this.cardTarget) {
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
    // Using `next()` to optimise INP
    next(() => {
      this._positionCard(target, event);
      this._showCallback(username).then((user) => {
        this.appEvents.trigger("user-card:after-show", { user });
      });
    });

    // We bind scrolling on mobile after cards are shown to hide them if user scrolls
    if (this.site.mobileView) {
      this._bindMobileScroll();
    }

    return false;
  }

  didInsertElement() {
    super.didInsertElement(...arguments);

    document.addEventListener("mousedown", this._clickOutsideHandler);
    document.addEventListener("keyup", this._escListener);

    _cardClickListenerSelectors.forEach((selector) => {
      document
        .querySelector(selector)
        .addEventListener("click", this._cardClickHandler);
    });

    this.appEvents.on(
      `d-editor:preview-click-${this.elementId}`,
      this,
      "_previewClick"
    );

    this.appEvents.on(
      `topic-header:trigger-${this.elementId}`,
      this,
      "_topicHeaderTrigger"
    );

    this.appEvents.on("card:close", this, "_close");
  }

  @bind
  _cardClickHandler(event) {
    if (this.avatarSelector) {
      const matched = this._showCardOnClick(
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
  }

  _showCardOnClick(event, selector, transformText) {
    const matchingEl = event.target.closest(selector);
    if (matchingEl) {
      if (wantsNewWindow(event)) {
        return true;
      }

      const shouldBubble = this._show(
        transformText(matchingEl),
        matchingEl,
        event
      );

      if (!shouldBubble) {
        event.preventDefault();
        event.stopPropagation();
      }
    }

    return false;
  }

  _topicHeaderTrigger(username, target, event) {
    this.set("isDocked", true);
    return this._show(username, target, event);
  }

  @bind
  _onScroll() {
    throttle(this, this._close, 1000);
  }

  _bindMobileScroll() {
    window.addEventListener(MOBILE_SCROLL_EVENT, this._onScroll);
  }

  _unbindMobileScroll() {
    window.removeEventListener(MOBILE_SCROLL_EVENT, this._onScroll);
  }

  _previewClick(target, event) {
    return this._show(target.innerText.replace(/^@/, ""), target, event);
  }

  _positionCard(target) {
    schedule("afterRender", async () => {
      if (this.site.desktopView) {
        this._menuInstance = await this.menu.show(target, {
          content: this.element,
          autoUpdate: false,
          identifier: "usercard",
          padding: {
            top: 10 + AVATAR_OVERFLOW_SIZE + headerOffset(),
            right: 10,
            bottom: 10,
            left: 10,
          },
          maxWidth: "unset",
        });
      } else {
        this._menuInstance = await this.menu.show(target, {
          content: this.element,
          strategy: "fixed",
          identifier: "usercard",
          computePosition: (content) => {
            content.style.left = "10px";
            content.style.right = "10px";
            content.style.top = 10 + AVATAR_OVERFLOW_SIZE + "px";
          },
        });
      }

      this.element.classList.toggle("docked-card", this.isDocked);

      // After the card is shown, focus on the first link
      //
      // note: we DO NOT use afterRender here cause _positionCard may
      // run afterwards, if we allowed this to happen the usercard
      // may be offscreen and we may scroll all the way to it on focus

      discourseLater(() => {
        this.element.querySelector("a.user-profile-link")?.focus();
      }, 350);
    });
  }

  @bind
  _hide() {
    if (!this.visible && this.site.mobileView) {
      document.querySelector(".card-cloak")?.classList.add("hidden");
    }

    this._menuInstance?.destroy();
  }

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
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);

    document.removeEventListener("mousedown", this._clickOutsideHandler);
    document.removeEventListener("keyup", this._escListener);

    _cardClickListenerSelectors.forEach((selector) => {
      document
        .querySelector(selector)
        .removeEventListener("click", this._cardClickHandler);
    });

    this.appEvents.off(
      `d-editor:preview-click-${this.elementId}`,
      this,
      "_previewClick"
    );

    this.appEvents.off(
      `topic-header:trigger-${this.elementId}`,
      this,
      "_topicHeaderTrigger"
    );

    this.appEvents.off("card:close", this, "_close");
    this._hide();
  }

  @bind
  _clickOutsideHandler(event) {
    if (
      !this.visible ||
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

  @bind
  _escListener(event) {
    if (this.visible && event.key === "Escape") {
      this.cardTarget?.focus();
      this._close();
    }
  }
}
