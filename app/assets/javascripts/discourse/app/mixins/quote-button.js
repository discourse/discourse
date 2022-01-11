import Mixin from "@ember/object/mixin";
import { propertyEqual } from "discourse/lib/computed";
import { selectedElement, selectedText } from "discourse/lib/utilities";
import { INPUT_DELAY } from "discourse-common/config/environment";
import KeyEnterEscape from "discourse/mixins/key-enter-escape";
import { action } from "@ember/object";
import discourseDebounce from "discourse-common/lib/debounce";
import { schedule } from "@ember/runloop";
import toMarkdown from "discourse/lib/to-markdown";

export function fixQuotes(str) {
  // u+201c “
  // u+201d ”
  return str.replace(/[\u201C\u201D]/g, '"');
}

function regexSafeStr(str) {
  return str.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

export default Mixin.create(KeyEnterEscape, {
  classNames: ["quote-button"],
  classNameBindings: ["visible", "_displayFastEditInput:fast-editing"],
  visible: false,
  editPost: null,
  quoteHandler: null,

  _isFastEditable: false,
  _displayFastEditInput: false,
  _fastEditInitalSelection: null,
  _fastEditNewSelection: null,
  _isSavingFastEdit: false,
  _canEditPost: false,

  _isMouseDown: false,
  _reselected: false,

  _hideButton() {
    this.quoteState.clear();
    this.set("visible", false);

    this.set("_isFastEditable", false);
    this.set("_displayFastEditInput", false);
    this.set("_fastEditInitalSelection", null);
    this.set("_fastEditNewSelection", null);
  },

  _selectionChanged() {
    if (this._displayFastEditInput) {
      return;
    }

    const quoteState = this.quoteState;

    const selection = window.getSelection();
    if (selection.isCollapsed) {
      if (this.visible) {
        this._hideButton();
      }
      return;
    }

    // ensure we selected content inside 1 post *only*
    //
    // TODO (martin) Allow for > 1 element's worth of content for chat
    let firstRange, requiredDataForQuote;
    for (let r = 0; r < selection.rangeCount; r++) {
      const range = selection.getRangeAt(r);
      const $selectionStart = $(range.startContainer);
      const $ancestor = $(range.commonAncestorContainer);

      if (this.quoteHandler.noCloseQuotableEl($selectionStart)) {
        return;
      }

      firstRange = firstRange || range;

      requiredDataForQuote = this.quoteHandler.getRequiredData(
        $ancestor,
        requiredDataForQuote
      );

      if (
        this.quoteHandler.noCloseContentEl($ancestor) ||
        !this.quoteHandler.hasRequiredData(requiredDataForQuote)
      ) {
        if (this.visible) {
          this._hideButton();
        }
        return;
      }
    }

    const _selectedElement = selectedElement();
    const _selectedText = selectedText();

    const $selectedElement = $(_selectedElement);
    const cooked = this.quoteHandler.findCooked($selectedElement);
    const markdownBody = toMarkdown(cooked.innerHTML);

    let opts = {
      full: _selectedText === markdownBody,
    };

    for (
      let element = _selectedElement;
      element && element.tagName !== "ARTICLE";
      element = element.parentElement
    ) {
      if (element.tagName === "ASIDE" && element.classList.contains("quote")) {
        this.quoteHandler.quoteStateOpts(element, opts);
        break;
      }
    }

    quoteState.selected(requiredDataForQuote, _selectedText, opts);
    this.set("visible", quoteState.buffer.length > 0);

    if (this.quoteHandler.canFastEdit) {
      const quoteRegExp = new RegExp(regexSafeStr(quoteState.buffer), "gi");
      this.quoteHandler.fastEdit(
        quoteState,
        quoteRegExp,
        markdownBody,
        requiredDataForQuote
      );
    }

    // avoid hard loops in quote selection unconditionally
    // this can happen if you triple click text in firefox
    if (this._prevSelection === _selectedText) {
      return;
    }

    this._prevSelection = _selectedText;

    // on Desktop, shows the button at the beginning of the selection
    // on Mobile, shows the button at the end of the selection
    const isMobileDevice = this.site.isMobileDevice;
    const { isIOS, isAndroid, isSafari, isOpera } = this.capabilities;
    const showAtEnd = isMobileDevice || isIOS || isAndroid || isOpera;

    // Don't mess with the original range as it results in weird behaviours
    // where certain browsers will deselect the selection
    const clone = firstRange.cloneRange();

    // create a marker element containing a single invisible character
    const markerElement = document.createElement("span");
    markerElement.appendChild(document.createTextNode("\ufeff"));

    // on mobile, collapse the range at the end of the selection
    if (showAtEnd) {
      clone.collapse();
    }
    // insert the marker
    clone.insertNode(markerElement);

    // retrieve the position of the marker
    const $markerElement = $(markerElement);
    const markerOffset = $markerElement.offset();
    const parentScrollLeft = $markerElement.parent().scrollLeft();
    const $quoteButton = $(this.element);

    // remove the marker
    const parent = markerElement.parentNode;
    parent.removeChild(markerElement);
    // merge back all text nodes so they don't get messed up
    parent.normalize();

    // work around Safari that would sometimes lose the selection
    if (isSafari) {
      this._reselected = true;
      selection.removeAllRanges();
      selection.addRange(clone);
    }

    // change the position of the button
    schedule("afterRender", () => {
      if (!this.element || this.isDestroying || this.isDestroyed) {
        return;
      }

      let top = markerOffset.top;
      let left = markerOffset.left + Math.max(0, parentScrollLeft);
      if (showAtEnd) {
        top = top + 25;
        left = Math.min(
          left + 10,
          window.innerWidth - this.element.clientWidth - 10
        );
      } else {
        top = top - $quoteButton.outerHeight() - 5;
      }

      $quoteButton.offset({ top, left });
    });
  },

  didInsertElement() {
    this._super(...arguments);

    const { isWinphone, isAndroid } = this.capabilities;
    const wait = isWinphone || isAndroid ? INPUT_DELAY : 25;
    const onSelectionChanged = () => {
      discourseDebounce(this, this._selectionChanged, wait);
    };

    $(document)
      .on("mousedown.quote-button", (e) => {
        this._prevSelection = null;
        this._isMouseDown = true;
        this._reselected = false;

        // prevents fast-edit input event to trigger mousedown
        if (e.target.classList.contains("fast-edit-input")) {
          return;
        }

        if (
          $(e.target).closest(".quote-button, .create, .share, .reply-new")
            .length === 0
        ) {
          this._hideButton();
        }
      })
      .on("mouseup.quote-button", (e) => {
        // prevents fast-edit input event to trigger mouseup
        if (e.target.classList.contains("fast-edit-input")) {
          return;
        }

        this._prevSelection = null;
        this._isMouseDown = false;
        onSelectionChanged();
      })
      .on("selectionchange.quote-button", () => {
        if (!this._isMouseDown && !this._reselected) {
          onSelectionChanged();
        }
      });
    this.appEvents.on("quote-button:quote", this, "insertQuote");
    this.appEvents.on("quote-button:edit", this, "_toggleFastEditForm");
  },

  willDestroyElement() {
    $(document)
      .off("mousedown.quote-button")
      .off("mouseup.quote-button")
      .off("selectionchange.quote-button");
    this.appEvents.off("quote-button:quote", this, "insertQuote");
    this.appEvents.off("quote-button:edit", this, "_toggleFastEditForm");
  },

  _saveFastEditDisabled: propertyEqual(
    "_fastEditInitalSelection",
    "_fastEditNewSelection"
  ),

  @action
  insertQuote() {
    this.attrs.selectText().then(() => this._hideButton());
  },

  @action
  _toggleFastEditForm() {
    if (this._isFastEditable) {
      this.toggleProperty("_displayFastEditInput");

      schedule("afterRender", () => {
        if (this.site.mobileView) {
          this.element.style.left = `${
            (window.innerWidth - this.element.clientWidth) / 2
          }px`;
        }
        document.querySelector("#fast-edit-input")?.focus();
      });
    } else {
      // todo: better name?
      return this.quoteHandler.toggleFastEdit();
    }
  },

  @action
  _saveFastEdit() {
    this.quoteHandler.saveFastEdit();
  },

  @action
  save() {
    if (this._displayFastEditInput && !this._saveFastEditDisabled) {
      this._saveFastEdit();
    }
  },

  @action
  cancelled() {
    this._hideButton();
  },

  @action
  share(source) {
    this.quoteHandler.share(source);
  },
});
