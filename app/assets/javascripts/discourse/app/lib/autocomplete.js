import { getOwner } from "@ember/owner";
import { cancel } from "@ember/runloop";
import { createPopper } from "@popperjs/core";
import $ from "jquery";
import { isDocumentRTL } from "discourse/lib/text-direction";
import TextareaTextManipulation from "discourse/lib/textarea-text-manipulation";
import Site from "discourse/models/site";
import { INPUT_DELAY } from "discourse-common/config/environment";
import discourseDebounce from "discourse-common/lib/debounce";
import { iconHTML } from "discourse-common/lib/icon-library";
import discourseLater from "discourse-common/lib/later";

/**
  This is a jQuery plugin to support autocompleting values in our text fields.

  @module $.fn.autocomplete
**/

export const SKIP = "skip";
export const CANCELLED_STATUS = "__CANCELLED";

const ALLOWED_LETTERS_REGEXP = /[\s[{(/]/;
let _autoCompletePopper, _inputTimeout;

const keys = {
  backSpace: 8,
  tab: 9,
  enter: 13,
  shift: 16,
  ctrl: 17,
  alt: 18,
  esc: 27,
  space: 32,
  leftWindows: 91,
  rightWindows: 92,
  pageUp: 33,
  pageDown: 34,
  end: 35,
  home: 36,
  leftArrow: 37,
  upArrow: 38,
  rightArrow: 39,
  downArrow: 40,
  insert: 45,
  deleteKey: 46,
  zero: 48,
  a: 65,
  z: 90,
};

export default function (options) {
  if (this.length === 0) {
    return;
  }

  if (options === "destroy" || options.updateData) {
    cancel(_inputTimeout);

    this[0].removeEventListener("keydown", handleKeyDown);
    this[0].removeEventListener("keyup", handleKeyUp);
    this[0].removeEventListener("paste", handlePaste);
    this[0].removeEventListener("click", closeAutocomplete);
    window.removeEventListener("click", closeAutocomplete);

    if (options === "destroy") {
      return;
    }
  }

  if (options && options.cancel && this.data("closeAutocomplete")) {
    this.data("closeAutocomplete")();
    return this;
  }

  if (this.length !== 1) {
    if (window.console) {
      window.console.log(
        "WARNING: passed multiple elements to $.autocomplete, skipping."
      );
      if (window.Error) {
        window.console.log(new window.Error().stack);
      }
    }
    return this;
  }

  if (options && typeof options.preserveKey === "undefined") {
    options.preserveKey = true;
  }

  const disabled = options && options.disabled;
  let wrap = null;
  let autocompleteOptions = null;
  let selectedOption = null;
  let completeStart = null;
  let me = this;
  let div = null;
  let scrollElement = null;
  let prevTerm = null;

  // By default, when the autocomplete popup is rendered it has the
  // first suggestion 'selected', and pressing enter key inserts
  // the first suggestion into the input box.
  // If you want to stop that behavior, i.e. have the popup renders
  // with no suggestions selected, set the `autoSelectFirstSuggestion`
  // option to false.
  // With this option set to false, users will have to select
  // a suggestion via the up/down arrow keys and then press enter
  // to insert it.
  if (!("autoSelectFirstSuggestion" in options)) {
    options.autoSelectFirstSuggestion = true;
  }

  // input is handled differently
  const isInput = me[0].tagName === "INPUT" && !options.treatAsTextarea;
  let inputSelectedItems = [];

  options.textManipulation ??= new TextareaTextManipulation(getOwner(me[0]), {
    textarea: me[0],
  });

  function handlePaste() {
    discourseLater(() => me.trigger("keydown"), 50);
  }

  function scrollAutocomplete() {
    if (!scrollElement && !div) {
      return;
    }

    const scrollingElement =
      scrollElement?.length > 0 ? scrollElement[0] : div[0];
    const selectedElement = getSelectedOptionElement();
    const selectedElementTop = selectedElement.offsetTop;
    const selectedElementBottom =
      selectedElementTop + selectedElement.clientHeight;

    // the top of the item is above the top of the scrollElement, so scroll UP
    if (selectedElementTop <= scrollingElement.scrollTop) {
      scrollingElement.scrollTo(0, selectedElementTop);

      // the bottom of the item is below the bottom of the div, so scroll DOWN
    } else if (
      selectedElementBottom >=
      scrollingElement.scrollTop + scrollingElement.clientHeight
    ) {
      scrollingElement.scrollTo(
        0,
        scrollingElement.scrollTop + selectedElement.clientHeight
      );
    }
  }

  function closeAutocomplete() {
    _autoCompletePopper?.destroy();
    options.onClose?.();
    div?.hide()?.remove();
    div = null;
    scrollElement = null;
    completeStart = null;
    autocompleteOptions = null;
    prevTerm = null;
    _autoCompletePopper = null;
  }

  function addInputSelectedItem(item, triggerChangeCallback) {
    let transformed,
      transformedItem = item;

    if (options.transformComplete) {
      transformedItem = options.transformComplete(transformedItem);
    }
    // dump what we have in single mode, just in case
    if (options.single) {
      inputSelectedItems = [];
    }
    transformed = Array.isArray(transformedItem)
      ? transformedItem
      : [transformedItem || item];

    const divs = transformed.map((itm) => {
      let d = $(
        `<div class='item'><span>${itm}<a class='remove' href>${iconHTML(
          "xmark"
        )}</a></span></div>`
      );
      const $parent = me.parent();
      const prev = $parent.find(".item:last");

      if (prev.length === 0) {
        me.parent().prepend(d);
      } else {
        prev.after(d);
      }

      inputSelectedItems.push(itm);
      return d[0];
    });

    if (options.onChangeItems && triggerChangeCallback) {
      options.onChangeItems(inputSelectedItems);
    }

    $(divs)
      .find("a")
      .click(function () {
        closeAutocomplete();
        inputSelectedItems.splice(
          $.inArray(transformedItem, inputSelectedItems),
          1
        );
        $(this).parent().parent().remove();
        if (options.single) {
          me.show();
        }
        if (options.onChangeItems) {
          options.onChangeItems(inputSelectedItems);
        }
        return false;
      });
  }

  let completeTerm = async function (term, event) {
    if (term) {
      if (isInput) {
        me.val("");
        if (options.single) {
          me.hide();
        }
        addInputSelectedItem(term, true);
      } else {
        if (options.transformComplete) {
          term = await options.transformComplete(term, event);
        }

        if (term) {
          // After completion is done our position for completeStart may have
          // drifted. This can happen if the TEXTAREA changed out-of-band between
          // the time autocomplete was first displayed and the time of completion
          // Specifically this may happen due to uploads which inject a placeholder
          // which is later replaced with a different length string.
          let pos = await guessCompletePosition({ completeTerm: true });
          let completeEnd = null;
          if (
            pos.completeStart !== undefined &&
            pos.completeEnd !== undefined
          ) {
            completeStart = pos.completeStart;
            completeEnd = pos.completeEnd;
          } else {
            completeStart = completeEnd =
              options.textManipulation.getCaretPosition();
          }

          options.textManipulation.replaceTerm({
            start: completeStart,
            end: completeEnd,
            term: (options.preserveKey ? options.key || "" : "") + term,
          });

          if (options && options.afterComplete) {
            options.afterComplete(options.textManipulation.value, event);
          }
        }
      }
    }
    closeAutocomplete();
  };

  if (isInput) {
    const width = Math.max(this.width(), 200);

    if (options.updateData) {
      wrap = this.parent();
      wrap.find(".item").remove();
      me.show();
    } else {
      wrap = this.wrap(
        "<div class='ac-wrap clearfix" + (disabled ? " disabled" : "") + "'/>"
      ).parent();

      if (!options.fullWidthWrap) {
        wrap.width(width);
      }
    }

    if (options.single && !options.width) {
      this.attr("class", `${this.attr("class")} fullwidth-input`);
    } else if (options.width) {
      this.css("width", options.width);
    }

    this.attr(
      "name",
      options.updateData ? this.attr("name") : this.attr("name") + "-renamed"
    );

    let vals = this.val().split(",");
    vals.forEach((x) => {
      if (x !== "") {
        if (options.reverseTransform) {
          x = options.reverseTransform(x);
        }
        if (options.single) {
          me.hide();
        }
        addInputSelectedItem(x, false);
      }
    });

    if (options.items) {
      options.items.forEach((item) => {
        if (options.single) {
          me.hide();
        }
        addInputSelectedItem(item, true);
      });
    }

    this.val("");
    completeStart = 0;
    wrap.click(function () {
      this.focus();
      return true;
    });
  }

  function markSelected() {
    getLinks().removeClass("selected");
    return $(getSelectedOptionElement()).addClass("selected");
  }

  function getSelectedOptionElement() {
    return getLinks()[selectedOption];
  }

  function getLinks() {
    return div.find("li a");
  }

  // a sane spot below cursor
  const BELOW = -32;

  function renderAutocomplete() {
    if (div) {
      div.hide().remove();
    }
    if (autocompleteOptions.length === 0) {
      return;
    }

    div = $(options.template({ options: autocompleteOptions }));

    let ul = div.find("ul");
    if (options.autoSelectFirstSuggestion) {
      selectedOption = 0;
      markSelected();
    } else {
      selectedOption = -1;
    }
    ul.find("li").click(async function ({ originalEvent }) {
      // this is required to prevent the default behaviour when clicking on a <a> tag
      originalEvent.preventDefault();
      originalEvent.stopPropagation();

      selectedOption = ul.find("li").index(this);
      // hack for Gboard, see meta.discourse.org/t/-/187009/24
      if (autocompleteOptions == null) {
        const opts = { ...options, _gboard_hack_force_lookup: true };
        const data = await dataSource(prevTerm, opts);
        if (data) {
          updateAutoComplete(data);
          await completeTerm(
            autocompleteOptions[selectedOption],
            originalEvent
          );
          if (!options.single) {
            me.focus();
          }
        }
      } else {
        await completeTerm(autocompleteOptions[selectedOption], originalEvent);
        if (!options.single) {
          me.focus();
        }
      }
    });

    if (options.appendSelector) {
      me.parents(options.appendSelector).append(div);
    } else {
      me.parent().append(div);
    }

    if (options.scrollElementSelector) {
      scrollElement = div.find(options.scrollElementSelector);
    }

    if (options.onRender) {
      options.onRender(autocompleteOptions);
    }

    if (isInput || options.treatAsTextarea) {
      _autoCompletePopper && _autoCompletePopper.destroy();
      _autoCompletePopper = createPopper(me[0], div[0], {
        placement: `${Site.currentProp("mobileView") ? "top" : "bottom"}-start`,
        modifiers: [
          {
            name: "offset",
            options: {
              offset: [0, 2],
            },
          },
        ],
      });
      return _autoCompletePopper;
    }

    let vOffset = 0;
    let pos = options.textManipulation.getCaretCoords(completeStart);

    if (options.treatAsTextarea) {
      vOffset = -32;
    }

    if (!isInput && !options.treatAsTextarea) {
      vOffset = div.height();

      const spaceOutside =
        window.innerHeight -
        me.outerHeight() -
        $("header.d-header").innerHeight();

      if (spaceOutside < vOffset && vOffset > pos.top) {
        vOffset = BELOW;
      }

      if (Site.currentProp("mobileView") && me.height() / 2 >= pos.top) {
        vOffset = BELOW;
      }
    }

    const mePos = me.position();

    let left;
    if (isDocumentRTL()) {
      left = mePos.left + pos.left - div.width();
    } else {
      let hOffset = 10;
      if (Site.currentProp("mobileView")) {
        if (me.width() / 2 <= pos.left) {
          hOffset = -div.width();
        }
      }
      left = mePos.left + pos.left + hOffset;
    }
    if (left < 0) {
      left = 0;
    }

    const offsetTop = me.offset().top;
    const borderTop = parseInt(me.css("border-top-width"), 10) || 0;
    if (mePos.top + pos.top + borderTop - vOffset + offsetTop < 30) {
      vOffset = BELOW;
    }

    div.css({
      position: "absolute",
      top: `${mePos.top + pos.top - vOffset + borderTop}px`,
      left: `${left}px`,
    });
  }

  function dataSource(term, opts) {
    const force = opts._gboard_hack_force_lookup;
    if (force) {
      delete opts._gboard_hack_force_lookup;
    }
    if (prevTerm === term && !force) {
      return SKIP;
    }

    prevTerm = term;
    if (term.length !== 0 && term.trim().length === 0) {
      closeAutocomplete();
      return null;
    } else {
      return opts.dataSource(term);
    }
  }

  function updateAutoComplete(r) {
    if (completeStart === null || r === SKIP) {
      return;
    }

    if (r && r.then && typeof r.then === "function") {
      if (div) {
        div.hide().remove();
      }
      r.then(updateAutoComplete);
      return;
    }

    // Allow an update method to cancel. This allows us to debounce
    // promises without leaking
    if (r === CANCELLED_STATUS) {
      return;
    }

    autocompleteOptions = r;
    if (!r || r.length === 0) {
      closeAutocomplete();
    } else {
      renderAutocomplete();
    }
  }

  // chain to allow multiples
  const oldClose = me.data("closeAutocomplete");
  me.data("closeAutocomplete", function () {
    if (oldClose) {
      oldClose();
    }
    closeAutocomplete();
  });

  async function checkTriggerRule(_opts) {
    const opts = {
      ..._opts,
      inCodeBlock: () => options.textManipulation.inCodeBlock(),
    };
    const shouldTrigger = await options.triggerRule?.(me[0], opts);
    return shouldTrigger ?? true;
  }

  async function handleKeyUp(e) {
    if (options.debounced) {
      discourseDebounce(this, performAutocomplete, e, INPUT_DELAY);
    } else {
      await performAutocomplete(e);
    }
  }

  async function performAutocomplete(e) {
    if ([keys.esc, keys.enter].includes(e.which)) {
      return true;
    }

    let cp = options.textManipulation.getCaretPosition();
    const key = options.textManipulation.value[cp - 1];

    if (options.key) {
      if (options.onKeyUp && key !== options.key) {
        let match = options.onKeyUp(options.textManipulation.value, cp);

        if (match) {
          completeStart = cp - match[0].length;
          let term = match[0].substring(1, match[0].length);
          updateAutoComplete(dataSource(term, options));
        }
      }
    }

    if (completeStart === null && cp > 0) {
      if (key === options.key) {
        let prevChar = options.textManipulation.value.charAt(cp - 2);
        if (
          (await checkTriggerRule()) &&
          (!prevChar || ALLOWED_LETTERS_REGEXP.test(prevChar))
        ) {
          completeStart = cp - 1;
          updateAutoComplete(dataSource("", options));
        }
      }
    } else if (completeStart !== null) {
      let term = options.textManipulation.value.substring(
        completeStart + (options.key ? 1 : 0),
        cp
      );
      updateAutoComplete(dataSource(term, options));
    }
  }

  async function guessCompletePosition(opts) {
    let prev, stopFound, term;
    let prevIsGood = true;
    let backSpace = opts?.backSpace;
    let completeTermOption = opts?.completeTerm;
    let caretPos = options.textManipulation.getCaretPosition();

    if (backSpace) {
      caretPos -= 1;
    }

    let start = null;
    let end = null;

    let initialCaretPos = caretPos;

    while (prevIsGood && caretPos >= 0) {
      caretPos -= 1;
      prev = options.textManipulation.value[caretPos];

      stopFound = prev === options.key;

      if (stopFound) {
        prev = options.textManipulation.value[caretPos - 1];
        const shouldTrigger = await checkTriggerRule({ backSpace });

        if (
          shouldTrigger &&
          (prev === undefined || ALLOWED_LETTERS_REGEXP.test(prev))
        ) {
          start = caretPos;
          term = options.textManipulation.value.substring(
            caretPos + 1,
            initialCaretPos
          );
          end = caretPos + term.length;
          break;
        }
      }
      prevIsGood = !/\s/.test(prev);
      if (completeTermOption) {
        prevIsGood ||= prev === " ";
      }
    }

    return { completeStart: start, completeEnd: end, term };
  }

  async function handleKeyDown(e) {
    let i, term, total, userToComplete;
    let cp;

    if (e.ctrlKey || e.altKey || e.metaKey) {
      return true;
    }

    if (options.allowAny) {
      // saves us wiring up a change event as well

      cancel(_inputTimeout);
      _inputTimeout = discourseLater(() => {
        if (inputSelectedItems.length === 0) {
          inputSelectedItems.push("");
        }

        const value = options.textManipulation.value;
        if (typeof inputSelectedItems[0] === "string" && value.length > 0) {
          inputSelectedItems.pop();
          inputSelectedItems.push(value);
          if (options.onChangeItems) {
            options.onChangeItems(inputSelectedItems);
          }
        }
      }, 50);
    }

    if (!options.key) {
      completeStart = 0;
    }

    if (e.which === keys.shift) {
      return;
    }

    if (completeStart === null && e.which === keys.backSpace && options.key) {
      let position = await guessCompletePosition({ backSpace: true });
      completeStart = position.completeStart;

      if (position.completeEnd) {
        updateAutoComplete(dataSource(position.term, options));
        return true;
      }
    }

    // ESC
    if (e.which === keys.esc) {
      if (div !== null) {
        closeAutocomplete();
        e.preventDefault();
        e.stopImmediatePropagation();
        return false;
      }
      return true;
    }

    if (completeStart !== null) {
      cp = options.textManipulation.getCaretPosition();

      // allow people to right arrow out of completion
      if (
        e.which === keys.rightArrow &&
        options.textManipulation.value[cp] === " "
      ) {
        closeAutocomplete();
        return true;
      }

      // If we've backspaced past the beginning, cancel unless no key
      if (cp <= completeStart && options.key) {
        closeAutocomplete();
        return true;
      }

      // Keyboard codes! So 80's.
      switch (e.which) {
        case keys.tab:
        case keys.enter:
          if (!autocompleteOptions) {
            closeAutocomplete();
            return true;
          }
          if (
            selectedOption >= 0 &&
            (userToComplete = autocompleteOptions[selectedOption])
          ) {
            await completeTerm(userToComplete, e);
          } else {
            // We're cancelling it, really.
            return true;
          }

          e.stopImmediatePropagation();
          e.preventDefault();
          return false;
        case keys.upArrow:
          selectedOption = selectedOption - 1;
          if (selectedOption < 0) {
            selectedOption = 0;
          }
          markSelected();
          scrollAutocomplete();
          e.preventDefault();
          return false;
        case keys.downArrow:
          if (!autocompleteOptions) {
            closeAutocomplete();
            return true;
          }

          total = autocompleteOptions.length;
          selectedOption = selectedOption + 1;
          if (selectedOption >= total) {
            selectedOption = total - 1;
          }
          if (selectedOption < 0) {
            selectedOption = 0;
          }
          markSelected();
          scrollAutocomplete();
          e.preventDefault();
          return false;
        case keys.backSpace:
          autocompleteOptions = null;
          cp--;

          if (cp < 0) {
            closeAutocomplete();

            if (isInput) {
              i = wrap.find("a:last");
              if (i) {
                i.click();
              }
            }
            return true;
          }

          term = options.textManipulation.value.substring(
            completeStart + (options.key ? 1 : 0),
            cp
          );

          if (completeStart === cp && term === options.key) {
            closeAutocomplete();
          }

          updateAutoComplete(dataSource(term, options));
          return true;
        default:
          autocompleteOptions = null;
          return true;
      }
    }
  }

  window.addEventListener("click", closeAutocomplete);
  this[0].addEventListener("click", closeAutocomplete);
  this[0].addEventListener("paste", handlePaste);
  this[0].addEventListener("keyup", handleKeyUp);
  this[0].addEventListener("keydown", handleKeyDown);

  return this;
}
