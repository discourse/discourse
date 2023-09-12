import { getOwner } from "discourse-common/lib/get-owner";
import Service, { inject as service } from "@ember/service";
import { isTesting } from "discourse-common/config/environment";
import { iconHTML } from "discourse-common/lib/icon-library";
import I18n from "I18n";
import { escape } from "pretty-text/sanitizer";
import isElementInViewport from "discourse/lib/is-element-in-viewport";
import discourseLater from "discourse-common/lib/later";
import { cancel } from "@ember/runloop";
import DTooltipInstance from "float-kit/lib/d-tooltip-instance";
import UserTipContainer from "discourse/components/user-tip-container";

const DELAY = 500;

export default class UserTips extends Service {
  @service tooltip;

  #instances = new Map();

  /**
   * @param {Object} options
   * @param {Integer} options.id
   * @param {Element} options.reference
   * @param {string} [options.buttonLabel]
   * @param {string} [options.buttonIcon]
   * @param {string} [options.placement]
   * @param {string} [options.content]
   * @param {string} [options.contentText]
   * @param {string} [options.titleText]
   * @param {function} [options.onDismiss]
   */
  showTip(options) {
    // Find if a similar instance has been scheduled for destroying recently
    // and cancel that
    const instance = this.#instances.get(options.id);

    if (instance) {
      if (instance.reference === options.reference) {
        return this.#cancelDestroyInstance(instance);
      } else {
        this.#destroyInstance(instance);
        this.#instances.delete(options.id);
      }
    }

    if (!options.reference) {
      return;
    }

    let buttonText = escape(I18n.t(options.buttonLabel || "user_tips.button"));
    if (options.buttonIcon) {
      buttonText = `${iconHTML(options.buttonIcon)} ${buttonText}`;
    }

    this.#instances.set(
      options.id,
      new DTooltipInstance(getOwner(this), options.reference, {
        identifier: "user-tip",
        interactive: true,
        closeOnScroll: false,
        closeOnClickOutside: false,
        placement: options.placement,
        component: UserTipContainer,
        data: {
          titleText: escape(options.titleText),
          contentHtml: options.contentHtml || null,
          contentText: options.contentText ? escape(options.contentText) : null,
          onDismiss: options.onDismiss,
          buttonText,
        },
      })
    );

    this.showNextTip();
  }

  hideTip(userTipId, force = false) {
    // Instances are not destroyed immediately because sometimes their
    // user tip is recreated immediately. This happens when Ember components
    // are re-rendered because a parent component has changed

    const instance = this.#instances.get(userTipId);
    if (!instance) {
      return;
    }

    if (force) {
      this.#destroyInstance(instance);
      this.#instances.delete(userTipId);
      this.showNextTip();
    } else if (!instance.destroyTimer) {
      instance.destroyTimer = discourseLater(() => {
        this.#destroyInstance(this.#instances.get(userTipId));
        this.#instances.delete(userTipId);
        this.showNextTip();
      }, DELAY);
    }
  }

  hideAll() {
    for (const [id, tip] of this.#instances.entries()) {
      this.#destroyInstance(tip);
      this.#instances.delete(id);
    }
  }

  showNextTip() {
    // Return early if a user tip is already visible and it is in viewport
    for (const tip of this.#instances.values()) {
      if (tip.expanded && isElementInViewport(tip.trigger)) {
        return;
      }
    }

    // Otherwise, try to find a user tip in the viewport
    let visibleTip;
    for (const tip of this.#instances.values()) {
      if (isElementInViewport(tip.trigger)) {
        visibleTip = tip;

        break;
      }
    }

    // If no instance was found, select first user tip
    const newTip = visibleTip || this.#instances.values().next();

    // Show only selected instance and hide all the other ones
    for (const tip of this.#instances.values()) {
      if (tip === newTip) {
        this.#showInstance(tip);
      } else {
        this.#hideInstance(tip);
      }
    }
  }

  #destroyInstance(instance) {
    if (instance.showTimer) {
      cancel(instance.showTimer);
      instance.showTimer = null;
    }

    if (instance.destroyTimer) {
      cancel(instance.destroyTimer);
      instance.destroyTimer = null;
    }

    instance.destroy();
  }

  #cancelDestroyInstance(instance) {
    if (instance.destroyTimer) {
      cancel(instance.destroyTimer);
      instance.destroyTimer = null;
    }
  }

  #showInstance(instance) {
    if (isTesting()) {
      this.tooltip.show(instance);
    } else if (!instance.showTimer) {
      instance.showTimer = discourseLater(() => {
        instance.showTimer = null;
        this.tooltip.show(instance);
      }, DELAY);
    }
  }

  #hideInstance(instance) {
    cancel(instance.showTimer);
    instance.showTimer = null;
    this.tooltip.close(instance);
  }
}
