import Mixin from "@ember/object/mixin";
import domUtils from "discourse-common/utils/dom-utils";
import { propertyEqual } from "discourse/lib/computed";
import { selectedElement, selectedText } from "discourse/lib/utilities";
import { INPUT_DELAY } from "discourse-common/config/environment";
import KeyEnterEscape from "discourse/mixins/key-enter-escape";
import { action } from "@ember/object";
import discourseDebounce from "discourse-common/lib/debounce";
import { schedule } from "@ember/runloop";
import toMarkdown from "discourse/lib/to-markdown";
import { regexSafeStr } from "discourse/lib/quote";

export default Mixin.create(KeyEnterEscape, {
  classNames: ["quote-button"],
  classNameBindings: ["visible", "_displayFastEditInput:fast-editing"],
  visible: false,
  editText: null,

  _isFastEditable: false,
  _displayFastEditInput: false,
  _fastEditInitalSelection: null,
  _fastEditNewSelection: null,
  _isSavingFastEdit: false,
  _canEditPost: false,

  _isMouseDown: false,
  _reselected: false,

  _hideButton() {
    if (this._isDestroyed()) {
      return;
    }
    this.quoteState.clear();
    this.set("visible", false);

    this.set("_isFastEditable", false);
    this.set("_displayFastEditInput", false);
    this.set("_fastEditInitalSelection", null);
    this.set("_fastEditNewSelection", null);
  },

  _isDestroyed() {
    return !this.element || this.isDestroying || this.isDestroyed;
  },

  _selectionChanged() {
    if (this._displayFastEditInput || this._isDestroyed()) {
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

    // TODO (martin) Allow for > 1 element's worth of content for chat,
    // post only allows one to be selected.
    let firstRange, requiredDataForQuote;
    for (let r = 0; r < selection.rangeCount; r++) {
      const range = selection.getRangeAt(r);
      const selectionStart = this._textNodeToElement(range.startContainer);
      const ancestor = this._textNodeToElement(range.commonAncestorContainer);

      if (this._noCloseQuotableEl(selectionStart)) {
        return;
      }

      firstRange = firstRange || range;

      requiredDataForQuote = this._getRequiredQuoteData(
        ancestor,
        requiredDataForQuote
      );

      if (
        this._noCloseContentEl(ancestor) ||
        !this._hasRequiredQuoteData(requiredDataForQuote)
      ) {
        if (this.visible) {
          this._hideButton();
        }
        return;
      }
    }

    const _selectedElement = this._textNodeToElement(selectedElement());
    const _selectedText = selectedText();

    const cooked = this._findCooked(_selectedElement);
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
        this._quoteStateOpts(element, opts);
        break;
      }
    }

    quoteState.selected(requiredDataForQuote, _selectedText, opts);
    this.set("visible", quoteState.buffer.length > 0);

    if (this.canFastEdit) {
      const quoteRegExp = new RegExp(regexSafeStr(quoteState.buffer), "gi");
      this._fastEdit(
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
    const markerOffset = domUtils.offset(markerElement);
    const parentScrollLeft = markerElement.parentElement.scrollLeft;

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
      if (this._isDestroyed()) {
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
        top = top - this.element.offsetHeight - 5;
      }

      // previously this was $element.offset({ top, left }) using
      // jQuery...this is a simplistic version of the massive jQuery
      // function which works well enough.
      this.element.style.top = top + "px";
      this.element.style.left = left + "px";
    });
  },

  didInsertElement() {
    this._super(...arguments);

    const { isWinphone, isAndroid } = this.capabilities;
    this.set(
      "selectionChangedWait",
      isWinphone || isAndroid ? INPUT_DELAY : 25
    );
    this.set("selectionChangedDebounceFn", () => {
      discourseDebounce(
        this,
        this._selectionChanged,
        this.selectionChangedWait
      );
    });

    document.addEventListener("mousedown", this._onMouseDown.bind(this));
    document.addEventListener("mouseup", this._onMouseUp.bind(this));
    document.addEventListener(
      "selectionchange",
      this._onSelectionChange.bind(this)
    );

    this.appEvents.on("quote-button:quote", this, "insertQuote");
    this.appEvents.on("quote-button:edit", this, "_toggleFastEditForm");
  },

  _onMouseDown(event) {
    this._prevSelection = null;
    this._isMouseDown = true;
    this._reselected = false;

    // prevents fast-edit input event to trigger mousedown
    if (event.target.classList.contains("fast-edit-input")) {
      return;
    }

    if (!event.target.closest(".quote-button, .create, .share, .reply-new")) {
      this._hideButton();
    }
  },

  _onMouseUp(event) {
    // prevents fast-edit input event to trigger mouseup
    if (event.target.classList.contains("fast-edit-input")) {
      return;
    }

    this._prevSelection = null;
    this._isMouseDown = false;
    this.selectionChangedDebounceFn();
  },

  _onSelectionChange() {
    if (!this._isMouseDown && !this._reselected) {
      this.selectionChangedDebounceFn();
    }
  },

  willDestroyElement() {
    document.removeEventListener("mousedown", this._onMouseUp.bind(this));
    document.removeEventListener("mouseup", this._onMouseDown.bind(this));
    document.removeEventListener(
      "selectionchange",
      this._onSelectionChange.bind(this)
    );
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
  cancelled() {
    this._hideButton();
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
      return this._toggleFastEdit();
    }
  },

  _fastEdit(quoteState, quoteRegExp, markdownBody, params = {}) {
    this._setCanEdit(params);

    const matches = markdownBody.match(quoteRegExp);
    if (
      quoteState.buffer.length < 1 ||
      quoteState.buffer.includes("|") || // tables are too complex
      quoteState.buffer.match(/\n/g) || // linebreaks are too complex
      matches?.length > 1 // duplicates are too complex
    ) {
      this.set("_isFastEditable", false);
      this.set("_fastEditInitalSelection", null);
      this.set("_fastEditNewSelection", null);
    } else if (matches?.length === 1) {
      this.set("_isFastEditable", true);
      this.set("_fastEditInitalSelection", quoteState.buffer);
      this.set("_fastEditNewSelection", quoteState.buffer);
    }
  },

  _textNodeToElement(node) {
    if (node.nodeType === Node.TEXT_NODE) {
      return node.parentNode;
    }
    return node;
  },
});
