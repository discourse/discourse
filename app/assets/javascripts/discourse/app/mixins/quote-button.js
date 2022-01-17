import Mixin from "@ember/object/mixin";
import { propertyEqual } from "discourse/lib/computed";
import { selectedElement, selectedText } from "discourse/lib/utilities";
import { INPUT_DELAY } from "discourse-common/config/environment";
import KeyEnterEscape from "discourse/mixins/key-enter-escape";
import { action } from "@ember/object";
import discourseDebounce from "discourse-common/lib/debounce";
import { next, schedule } from "@ember/runloop";
import toMarkdown from "discourse/lib/to-markdown";
import { regexSafeStr } from "discourse/lib/quote";

export default Mixin.create(KeyEnterEscape, {
  classNames: ["quote-button"],
  classNameBindings: [
    "visible",
    "_displayFastEditInput:fast-editing",
    "animated",
  ],
  visible: false,
  animated: false,
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
    this.quoteState.clear();
    this.set("visible", false);
    this.set("animated", false);

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

    // TODO (martin) Allow for > 1 element's worth of content for chat,
    // post only allows one to be selected.
    let firstRange, requiredDataForQuote;
    for (let r = 0; r < selection.rangeCount; r++) {
      const range = selection.getRangeAt(r);
      const $selectionStart = $(range.startContainer);
      const $ancestor = $(range.commonAncestorContainer);

      if (this._noCloseQuotableEl($selectionStart)) {
        return;
      }

      firstRange = firstRange || range;

      requiredDataForQuote = this._getRequiredQuoteData(
        $ancestor,
        requiredDataForQuote
      );

      if (
        this._noCloseContentEl($ancestor) ||
        !this._hasRequiredQuoteData(requiredDataForQuote)
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
    const cooked = this._findCooked($selectedElement);
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

      if (isIOS) {
        // The selection-handles on iOS have a hit area of ~50px radius
        // so we need to make sure our buttons are outside that radius

        const safeRadius = 50;
        const endHandlePosition = markerOffset;
        const width = this.element.clientWidth;

        const possiblePositions = [
          { top, left },
          { top, left: endHandlePosition.left - width - safeRadius - 10 }, // move to left
          { top, left: left + safeRadius }, // move to right
          { top: top + safeRadius, left: endHandlePosition.left - width / 2 }, // centered below end handle
        ];

        let newPos;
        for (const pos of possiblePositions) {
          if (pos.left < 0 || pos.left + width + 10 > window.innerWidth) {
            continue; // Offscreen
          }

          const clearOfEndHandle =
            pos.top - endHandlePosition.top >= safeRadius ||
            pos.left + width <= endHandlePosition.left - safeRadius ||
            pos.left >= endHandlePosition.left + safeRadius;

          if (clearOfEndHandle) {
            newPos = pos;
            break;
          }
        }

        if (newPos) {
          left = newPos.left;
          top = newPos.top;
        }
      }

      $quoteButton.offset({ top, left });

      if (!this.animated) {
        // We only enable CSS transitions after the initial positioning
        // otherwise the button can appear to fly in from off-screen
        next(() => this.set("animated", true));
      }
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
});
