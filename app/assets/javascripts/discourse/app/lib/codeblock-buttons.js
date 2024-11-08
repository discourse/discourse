import { guidFor } from "@ember/object/internals";
import { cancel } from "@ember/runloop";
import FullscreenCodeModal from "discourse/components/modal/fullscreen-code";
import Mobile from "discourse/lib/mobile";
import { clipboardCopy } from "discourse/lib/utilities";
import { getOwnerWithFallback } from "discourse-common/lib/get-owner";
import { iconHTML } from "discourse-common/lib/icon-library";
import discourseLater from "discourse-common/lib/later";
import { bind } from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

// Use to attach copy/fullscreen buttons to a block of code, either
// within the post stream or for a regular element that contains
// a pre > code HTML structure.
//
// Usage (post):
//
// const cb = new CodeblockButtons({
//   showFullscreen: true,
//   showCopy: true,
// });
// cb.attachToPost(post, postElement);
//
// Usage (generic):
//
// const cb = new CodeblockButtons({
//   showFullscreen: true,
//   showCopy: true,
// });
// cb.attachToGeneric(element);
//
// Make sure to run .cleanup() on the instance once you are done to
// remove click events.
export default class CodeblockButtons {
  constructor(opts = {}) {
    this._codeblockButtonClickHandlers = {};
    this._fadeCopyCodeblocksRunners = {};
    opts = Object.assign(
      {
        showFullscreen: true,
        showCopy: true,
      },
      opts
    );

    this.showFullscreen = opts.showFullscreen;
    this.showCopy = opts.showCopy;
  }

  attachToPost(post, postElement) {
    let codeBlocks = this._getCodeBlocks(postElement);
    if (!codeBlocks.length || !post) {
      return;
    }

    this._createButtons(codeBlocks);
    this._storeClickHandler(post.id, postElement);
    this._addClickEvent(postElement);
  }

  attachToGeneric(element) {
    let codeBlocks = this._getCodeBlocks(element);
    if (!codeBlocks.length) {
      return;
    }

    this._createButtons(codeBlocks);
    const commandId = guidFor(element);
    this._storeClickHandler(commandId, element);
    this._addClickEvent(element);
  }

  cleanup() {
    Object.values(this._codeblockButtonClickHandlers || {}).forEach((handler) =>
      handler.removeEventListener("click", this._handleClick)
    );

    Object.values(this._fadeCopyCodeblocksRunners || {}).forEach((runner) =>
      cancel(runner)
    );

    this._codeblockButtonClickHandlers = {};
    this._fadeCopyCodeblocksRunners = {};
  }

  _storeClickHandler(identifier, element) {
    if (this._codeblockButtonClickHandlers[identifier]) {
      this._codeblockButtonClickHandlers[identifier].removeEventListener(
        "click",
        this._handleClick
      );

      delete this._codeblockButtonClickHandlers[identifier];
    }

    this._codeblockButtonClickHandlers[identifier] = element;
  }

  _getCodeBlocks(element) {
    return element.querySelectorAll(
      ":scope > pre > code, :scope :not(article):not(blockquote) > pre > code"
    );
  }

  _createButtons(codeBlocks) {
    codeBlocks.forEach((codeBlock) => {
      const wrapperEl = document.createElement("div");
      wrapperEl.classList.add("codeblock-button-wrapper");
      codeBlock.before(wrapperEl);

      if (this.showCopy) {
        const copyButton = document.createElement("button");
        copyButton.classList.add("btn", "nohighlight", "copy-cmd", "btn-flat");
        copyButton.ariaLabel = I18n.t("copy_codeblock.copy");
        copyButton.innerHTML = iconHTML("copy");
        wrapperEl.appendChild(copyButton);
        wrapperEl.style.right = `${
          codeBlock.offsetWidth - codeBlock.clientWidth
        }px`;
      }

      if (this.showFullscreen && !Mobile.isMobileDevice) {
        const fullscreenButton = document.createElement("button");
        fullscreenButton.classList.add(
          "btn",
          "nohighlight",
          "fullscreen-cmd",
          "btn-flat"
        );
        fullscreenButton.ariaLabel = I18n.t("copy_codeblock.fullscreen");
        fullscreenButton.innerHTML = iconHTML("discourse-expand");
        wrapperEl.appendChild(fullscreenButton);
      }

      codeBlock.parentElement.classList.add("codeblock-buttons");
    });
  }

  _addClickEvent(element) {
    element.addEventListener("click", this._handleClick, false);
  }

  @bind
  _handleClick(event) {
    if (
      !event.target.classList.contains("copy-cmd") &&
      !event.target.classList.contains("fullscreen-cmd")
    ) {
      return;
    }

    const action = event.target.classList.contains("fullscreen-cmd")
      ? "fullscreen"
      : "copy";
    const button = event.target;
    const codeEl = button.parentElement.parentElement.querySelector("code");

    if (codeEl) {
      // replace any weird whitespace characters with a proper '\u20' whitespace
      const text = codeEl.innerText
        .replace(
          /[\f\v\u00a0\u1680\u2000-\u200a\u202f\u205f\u3000\ufeff]/g,
          " "
        )
        .trim();

      if (action === "copy") {
        const result = clipboardCopy(text);
        if (result?.then) {
          result.then(() => {
            this._copyComplete(button);
          });
        } else if (result) {
          this._copyComplete(button);
        }
      } else if (action === "fullscreen") {
        const modal = getOwnerWithFallback(this).lookup("service:modal");
        modal.show(FullscreenCodeModal, {
          model: {
            code: text,
            codeClasses: codeEl.className,
          },
        });
      }
    }
  }

  _copyComplete(button) {
    button.classList.add("action-complete");
    const state = button.innerHTML;
    button.innerHTML = I18n.t("copy_codeblock.copied");

    const commandId = guidFor(button);

    if (this._fadeCopyCodeblocksRunners[commandId]) {
      cancel(this._fadeCopyCodeblocksRunners[commandId]);
      delete this._fadeCopyCodeblocksRunners[commandId];
    }

    this._fadeCopyCodeblocksRunners[commandId] = discourseLater(() => {
      button.classList.remove("action-complete");
      button.innerHTML = state;
      delete this._fadeCopyCodeblocksRunners[commandId];
    }, 3000);
  }
}
