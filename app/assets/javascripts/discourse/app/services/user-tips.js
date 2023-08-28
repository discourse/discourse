import Service from "@ember/service";
import { isTesting } from "discourse-common/config/environment";
import { iconHTML } from "discourse-common/lib/icon-library";
import I18n from "I18n";
import { escape } from "pretty-text/sanitizer";
import tippy from "tippy.js";
import isElementInViewport from "discourse/lib/is-element-in-viewport";
import discourseLater from "discourse-common/lib/later";
import { cancel } from "@ember/runloop";

const TIPPY_DELAY = 500;

export default class UserTips extends Service {
  #instances = new Map();

  /**
   * @param {Object} options
   * @param {Integer} options.id
   * @param {Element} options.reference
   * @param {string} [options.buttonLabel]
   * @param {string} [options.buttonIcon]
   * @param {string} [options.placement]
   * @param {Element} [options.appendTo]
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
      tippy(options.reference, {
        hideOnClick: false,
        trigger: "manual",
        theme: "user-tip",
        zIndex: "", // reset z-index to use inherited value from the parent
        duration: TIPPY_DELAY,

        arrow: iconHTML("tippy-rounded-arrow"),
        placement: options.placement,
        appendTo: options.appendTo,

        interactive: true, // for buttons in content
        allowHTML: true,

        content:
          options.content ||
          `<div class='user-tip__container'>
            <div class='user-tip__title'>${escape(options.titleText)}</div>
            <div class='user-tip__content'>${
              options.contentHtml || escape(options.contentText)
            }</div>
            <div class='user-tip__buttons'>
              <button class="btn btn-primary">${buttonText}</button>
            </div>
          </div>`,

        onCreate(tippyInstance) {
          // Used to set correct z-index property on root tippy element
          tippyInstance.popper.classList.add("user-tip");

          tippyInstance.popper
            .querySelector(".btn")
            .addEventListener("click", (event) => {
              options.onDismiss?.();
              event.preventDefault();
            });
        },
      })
    );

    this.showNextTip();
  }

  hideTip(userTipId, force = false) {
    // Tippy instances are not destroyed immediately because sometimes there
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
      }, TIPPY_DELAY);
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
      if (tip.state.isVisible && isElementInViewport(tip.reference)) {
        return;
      }
    }

    // Otherwise, try to find a user tip in the viewport
    let visibleTip;
    for (const tip of this.#instances.values()) {
      if (isElementInViewport(tip.reference)) {
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
      instance.show();
    } else if (!instance.showTimer) {
      instance.showTimer = discourseLater(() => {
        instance.showTimer = null;
        if (!instance.state.isDestroyed) {
          instance.show();
        }
      }, TIPPY_DELAY);
    }
  }

  #hideInstance(instance) {
    cancel(instance.showTimer);
    instance.showTimer = null;
    instance.hide();
  }
}
