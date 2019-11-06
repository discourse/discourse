import { cancel } from "@ember/runloop";
import { later } from "@ember/runloop";
/**
  This is a jQuery plugin to support autocompleting values in our text fields.

  @module $.fn.autocomplete
**/
import { iconHTML } from "discourse-common/lib/icon-library";
export const CANCELLED_STATUS = "__CANCELLED";
import { setCaretPosition, caretPosition } from "discourse/lib/utilities";

const allowedLettersRegex = /[\s\t\[\{\(\/]/;

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
  z: 90
};

let inputTimeout;

export default function(options) {
  const autocompletePlugin = this;

  if (this.length === 0) return;

  if (options === "destroy" || options.updateData) {
    cancel(inputTimeout);

    $(this)
      .off("keyup.autocomplete")
      .off("keydown.autocomplete")
      .off("paste.autocomplete")
      .off("click.autocomplete");

    $(window).off("click.autocomplete");

    if (options === "destroy") return;
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

  const disabled = options && options.disabled;
  let wrap = null;
  let autocompleteOptions = null;
  let selectedOption = null;
  let completeStart = null;
  let completeEnd = null;
  let me = this;
  let div = null;
  let prevTerm = null;

  // input is handled differently
  const isInput = this[0].tagName === "INPUT" && !options.treatAsTextarea;
  let inputSelectedItems = [];

  function closeAutocomplete() {
    if (div) {
      div.hide().remove();
    }
    div = null;
    completeStart = null;
    autocompleteOptions = null;
    prevTerm = null;
  }

  function addInputSelectedItem(item, triggerChangeCallback) {
    var transformed,
      transformedItem = item;

    if (options.transformComplete) {
      transformedItem = options.transformComplete(transformedItem);
    }
    // dump what we have in single mode, just in case
    if (options.single) {
      inputSelectedItems = [];
    }
    transformed = _.isArray(transformedItem)
      ? transformedItem
      : [transformedItem || item];

    const divs = transformed.map(itm => {
      let d = $(
        `<div class='item'><span>${itm}<a class='remove' href>${iconHTML(
          "times"
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
      .click(function() {
        closeAutocomplete();
        inputSelectedItems.splice(
          $.inArray(transformedItem, inputSelectedItems),
          1
        );
        $(this)
          .parent()
          .parent()
          .remove();
        if (options.single) {
          me.show();
        }
        if (options.onChangeItems) {
          options.onChangeItems(inputSelectedItems);
        }
        return false;
      });
  }

  var completeTerm = function(term) {
    if (term) {
      if (isInput) {
        me.val("");
        if (options.single) {
          me.hide();
        }
        addInputSelectedItem(term, true);
      } else {
        if (options.transformComplete) {
          term = options.transformComplete(term);
        }

        if (term) {
          var text = me.val();
          text =
            text.substring(0, completeStart) +
            (options.key || "") +
            term +
            " " +
            text.substring(completeEnd + 1, text.length);
          me.val(text);
          setCaretPosition(me[0], completeStart + 1 + term.length);

          if (options && options.afterComplete) {
            options.afterComplete(text);
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
      this.css("width", "100%");
    } else if (options.width) {
      this.css("width", options.width);
    } else {
      this.width(150);
    }

    this.attr(
      "name",
      options.updateData ? this.attr("name") : this.attr("name") + "-renamed"
    );

    var vals = this.val().split(",");
    vals.forEach(x => {
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
      options.items.forEach(item => {
        if (options.single) {
          me.hide();
        }
        addInputSelectedItem(item, true);
      });
    }

    this.val("");
    completeStart = 0;
    wrap.click(function() {
      autocompletePlugin.focus();
      return true;
    });
  }

  function markSelected() {
    const links = div.find("li a");
    links.removeClass("selected");
    return $(links[selectedOption]).addClass("selected");
  }

  // a sane spot below cursor
  const BELOW = -32;

  function renderAutocomplete() {
    if (div) {
      div.hide().remove();
    }
    if (autocompleteOptions.length === 0) return;

    div = $(options.template({ options: autocompleteOptions }));

    var ul = div.find("ul");
    selectedOption = 0;
    markSelected();
    ul.find("li").click(function() {
      selectedOption = ul.find("li").index(this);
      completeTerm(autocompleteOptions[selectedOption]);
      return false;
    });
    var pos = null;
    var vOffset = 0;
    var hOffset = 0;

    if (isInput) {
      pos = {
        left: 0,
        top: 0
      };
      vOffset = BELOW;
      hOffset = 0;
    } else {
      pos = me.caretPosition({
        pos: completeStart + 1
      });

      hOffset = 10;
      if (options.treatAsTextarea) vOffset = -32;
    }

    div.css({
      left: "-1000px"
    });

    if (options.appendSelector) {
      me.parents(options.appendSelector).append(div);
    } else {
      me.parent().append(div);
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

      if (Discourse.Site.currentProp("mobileView")) {
        if (me.height() / 2 >= pos.top) {
          vOffset = BELOW;
        }
        if (me.width() / 2 <= pos.left) {
          hOffset = -div.width();
        }
      }
    }

    var mePos = me.position();

    var borderTop = parseInt(me.css("border-top-width"), 10) || 0;

    let left = mePos.left + pos.left + hOffset;
    if (left < 0) {
      left = 0;
    }

    const offsetTop = me.offset().top;
    if (mePos.top + pos.top + borderTop - vOffset + offsetTop < 30) {
      vOffset = BELOW;
    }

    div.css({
      position: "absolute",
      top: mePos.top + pos.top - vOffset + borderTop + "px",
      left: left + "px"
    });
  }

  const SKIP = "skip";

  function dataSource(term, opts) {
    if (prevTerm === term) {
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
    if (completeStart === null || r === SKIP) return;

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
  me.data("closeAutocomplete", function() {
    if (oldClose) {
      oldClose();
    }
    closeAutocomplete();
  });

  $(window).on("click.autocomplete", () => closeAutocomplete());
  $(this).on("click.autocomplete", () => closeAutocomplete());

  $(this).on("paste.autocomplete", () => {
    later(() => me.trigger("keydown"), 50);
  });

  function checkTriggerRule(opts) {
    return options.triggerRule ? options.triggerRule(me[0], opts) : true;
  }

  $(this).on("keyup.autocomplete", function(e) {
    if ([keys.esc, keys.enter].indexOf(e.which) !== -1) return true;

    let cp = caretPosition(me[0]);
    const key = me[0].value[cp - 1];

    if (options.key) {
      if (options.onKeyUp && key !== options.key) {
        let match = options.onKeyUp(me.val(), cp);
        if (match) {
          completeStart = cp - match[0].length;
          completeEnd = completeStart + match[0].length - 1;
          let term = match[0].substring(1, match[0].length);
          updateAutoComplete(dataSource(term, options));
        }
      }
    }

    if (completeStart === null && cp > 0) {
      if (key === options.key) {
        var prevChar = me.val().charAt(cp - 2);
        if (
          checkTriggerRule() &&
          (!prevChar || allowedLettersRegex.test(prevChar))
        ) {
          completeStart = completeEnd = cp - 1;
          updateAutoComplete(dataSource("", options));
        }
      }
    } else if (completeStart !== null) {
      let term = me.val().substring(completeStart + (options.key ? 1 : 0), cp);
      updateAutoComplete(dataSource(term, options));
    }
  });

  $(this).on("keydown.autocomplete", function(e) {
    var c, i, initial, prev, prevIsGood, stopFound, term, total, userToComplete;
    let cp;

    if (e.ctrlKey || e.altKey || e.metaKey) {
      return true;
    }

    if (options.allowAny) {
      // saves us wiring up a change event as well

      cancel(inputTimeout);
      inputTimeout = later(function() {
        if (inputSelectedItems.length === 0) {
          inputSelectedItems.push("");
        }

        if (_.isString(inputSelectedItems[0]) && me.val().length > 0) {
          inputSelectedItems.pop();
          inputSelectedItems.push(me.val());
          if (options.onChangeItems) {
            options.onChangeItems(inputSelectedItems);
          }
        }
      }, 50);
    }

    if (!options.key) {
      completeStart = 0;
    }
    if (e.which === keys.shift) return;
    if (completeStart === null && e.which === keys.backSpace && options.key) {
      c = caretPosition(me[0]);
      c -= 1;
      initial = c;
      prevIsGood = true;
      while (prevIsGood && c >= 0) {
        c -= 1;
        prev = me[0].value[c];
        stopFound = prev === options.key;
        if (stopFound) {
          prev = me[0].value[c - 1];
          if (
            checkTriggerRule({ backSpace: true }) &&
            (!prev || allowedLettersRegex.test(prev))
          ) {
            completeStart = c;
            cp = completeEnd = initial;
            term = me[0].value.substring(c + 1, initial);
            updateAutoComplete(dataSource(term, options));
            return true;
          }
        }
        prevIsGood = /[a-zA-Z\.-]/.test(prev);
      }
    }

    // ESC
    if (e.which === keys.esc) {
      if (div !== null) {
        closeAutocomplete();
        return false;
      }
      return true;
    }

    if (completeStart !== null) {
      cp = caretPosition(me[0]);

      // allow people to right arrow out of completion
      if (e.which === keys.rightArrow && me[0].value[cp] === " ") {
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
        case keys.enter:
        case keys.tab:
          if (!autocompleteOptions) return true;
          if (
            selectedOption >= 0 &&
            (userToComplete = autocompleteOptions[selectedOption])
          ) {
            completeTerm(userToComplete);
          } else {
            // We're cancelling it, really.
            return true;
          }
          e.stopImmediatePropagation();
          return false;
        case keys.upArrow:
          selectedOption = selectedOption - 1;
          if (selectedOption < 0) {
            selectedOption = 0;
          }
          markSelected();
          return false;
        case keys.downArrow:
          total = autocompleteOptions.length;
          selectedOption = selectedOption + 1;
          if (selectedOption >= total) {
            selectedOption = total - 1;
          }
          if (selectedOption < 0) {
            selectedOption = 0;
          }
          markSelected();
          return false;
        case keys.backSpace:
          completeEnd = cp;
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

          term = me.val().substring(completeStart + (options.key ? 1 : 0), cp);

          if (completeStart === cp && term === options.key) {
            closeAutocomplete();
          }

          updateAutoComplete(dataSource(term, options));
          return true;
        default:
          completeEnd = cp;
          return true;
      }
    }
  });

  return this;
}
