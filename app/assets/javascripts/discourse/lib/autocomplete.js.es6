/**
  This is a jQuery plugin to support autocompleting values in our text fields.

  @module $.fn.autocomplete
**/
export var CANCELLED_STATUS = "__CANCELLED";

const allowedLettersRegex = /[\s\t\[\{\(\/]/;

var keys = {
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


let inputTimeout;

export default function(options) {
  var autocompletePlugin = this;

  if (this.length === 0) return;

  if (options === 'destroy') {
    Ember.run.cancel(inputTimeout);

    $(this).off('keyup.autocomplete')
           .off('keydown.autocomplete')
           .off('paste.autocomplete')
           .off('click.autocomplete');

    return;
  }

  if (options && options.cancel && this.data("closeAutocomplete")) {
    this.data("closeAutocomplete")();
    return this;
  }

  if (this.length !== 1) {
    if (window.console) {
      window.console.log("WARNING: passed multiple elements to $.autocomplete, skipping.");
      if (window.Error) {
        window.console.log((new window.Error()).stack);
      }
    }
    return this;
  }

  var disabled = options && options.disabled;
  var wrap = null;
  var autocompleteOptions = null;
  var selectedOption = null;
  var completeStart = null;
  var completeEnd = null;
  var me = this;
  var div = null;
  var prevTerm = null;

  // input is handled differently
  var isInput = this[0].tagName === "INPUT";
  var inputSelectedItems = [];

  var closeAutocomplete = function() {
    if (div) {
      div.hide().remove();
    }
    div = null;
    completeStart = null;
    autocompleteOptions = null;
    prevTerm = null;
  };

  var addInputSelectedItem = function(item) {
    var transformed,
        transformedItem = item;

    if (options.transformComplete) { transformedItem = options.transformComplete(transformedItem); }
    // dump what we have in single mode, just in case
    if (options.single) { inputSelectedItems = []; }
    transformed = _.isArray(transformedItem) ? transformedItem : [transformedItem || item];

    var divs = transformed.map(function(itm) {
      var d = $("<div class='item'><span>" + itm + "<a class='remove' href><i class='fa fa-times'></i></a></span></div>");
      var prev = me.parent().find('.item:last');
      if (prev.length === 0) {
        me.parent().prepend(d);
      } else {
        prev.after(d);
      }
      inputSelectedItems.push(itm);
      return d[0];
    });

    if (options.onChangeItems) { options.onChangeItems(inputSelectedItems); }

    $(divs).find('a').click(function() {
      closeAutocomplete();
      inputSelectedItems.splice($.inArray(transformedItem, inputSelectedItems), 1);
      $(this).parent().parent().remove();
      if (options.single) {
        me.show();
      }
      if (options.onChangeItems) {
        options.onChangeItems(inputSelectedItems);
      }
      return false;
    });
  };

  var completeTerm = function(term) {
    if (term) {
      if (isInput) {
        me.val("");
        if(options.single){
          me.hide();
        }
        addInputSelectedItem(term);
      } else {
        if (options.transformComplete) {
          term = options.transformComplete(term);
        }

        if (term) {
          var text = me.val();
          text = text.substring(0, completeStart) + (options.key || "") + term + ' ' + text.substring(completeEnd + 1, text.length);
          me.val(text);
          Discourse.Utilities.setCaretPosition(me[0], completeStart + 1 + term.length);

          if (options && options.afterComplete) {
            options.afterComplete(text);
          }
        }
      }
    }
    closeAutocomplete();
  };

  if (isInput) {
    var width = this.width();
    wrap = this.wrap("<div class='ac-wrap clearfix" + (disabled ? " disabled": "") +  "'/>").parent();
    wrap.width(width);
    if(options.single) {
      this.css("width","100%");
    } else {
      this.width(150);
    }
    this.attr('name', this.attr('name') + "-renamed");
    var vals = this.val().split(",");
    _.each(vals,function(x) {
      if (x !== "") {
        if (options.reverseTransform) {
          x = options.reverseTransform(x);
        }
        addInputSelectedItem(x);
      }
    });
    if(options.items) {
      _.each(options.items, function(item){
        addInputSelectedItem(item);
      });
    }
    this.val("");
    completeStart = 0;
    wrap.click(function() {
      autocompletePlugin.focus();
      return true;
    });
  }

  var markSelected = function() {
    var links = div.find('li a');
    links.removeClass('selected');
    return $(links[selectedOption]).addClass('selected');
  };

  var renderAutocomplete = function() {
    if (div) {
      div.hide().remove();
    }
    if (autocompleteOptions.length === 0) return;

    div = $(options.template({ options: autocompleteOptions }));

    var ul = div.find('ul');
    selectedOption = 0;
    markSelected();
    ul.find('li').click(function() {
      selectedOption = ul.find('li').index(this);
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
      vOffset = -32;
      hOffset = 0;
    } else {
      pos = me.caretPosition({
        pos: completeStart,
        key: options.key
      });
      hOffset = 27;
    }
    div.css({
      left: "-1000px"
    });

    me.parent().append(div);

    if(!isInput){
      vOffset = div.height();
    }

    if (Discourse.Site.currentProp('mobileView') && !isInput) {
      div.css('width', 'auto');

      if ((me.height() / 2) >= pos.top) { vOffset = -23; }
      if ((me.width() / 2) <= pos.left) { hOffset = -div.width(); }
    }

    var mePos = me.position();
    var borderTop = parseInt(me.css('border-top-width'), 10) || 0;
    div.css({
      position: 'absolute',
      top: (mePos.top + pos.top - vOffset + borderTop) + 'px',
      left: (mePos.left + pos.left + hOffset) + 'px'
    });
  };

  const SKIP = "skip";

  const dataSource = (term, opts) => {
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
  };

  const updateAutoComplete = function(r) {

    if (completeStart === null || r === SKIP) return;

    if (r && r.then && typeof(r.then) === "function") {
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
  };

  // chain to allow multiples
  var oldClose = me.data("closeAutocomplete");
  me.data("closeAutocomplete", function() {
    if (oldClose) {
      oldClose();
    }
    closeAutocomplete();
  });

  $(this).on('click.autocomplete', function() {
    closeAutocomplete();
  });

  $(this).on('paste.autocomplete', function() {
    _.delay(function(){
      me.trigger("keydown");
    }, 50);
  });

  const checkTriggerRule = (opts) => {
    if (options.triggerRule) {
      return options.triggerRule(me[0], opts);
    } else {
      return true;
    }
  };

  $(this).on('keyup.autocomplete', function(e) {
    if ([keys.esc, keys.enter].indexOf(e.which) !== -1) return true;

    var caretPosition = Discourse.Utilities.caretPosition(me[0]);

    if (options.key && completeStart === null && caretPosition > 0) {
      var key = me[0].value[caretPosition-1];
      if (key === options.key) {
        var prevChar = me.val().charAt(caretPosition-2);
        if (checkTriggerRule() && (!prevChar || allowedLettersRegex.test(prevChar))) {
          completeStart = completeEnd = caretPosition-1;
          updateAutoComplete(dataSource("", options));
        }
      }
    } else if (completeStart !== null) {
      var term = me.val().substring(completeStart + (options.key ? 1 : 0), caretPosition);
      updateAutoComplete(dataSource(term, options));
    }
  });

  $(this).on('keydown.autocomplete', function(e) {
    var c, caretPosition, i, initial, prev, prevIsGood, stopFound, term, total, userToComplete;

    if(e.ctrlKey || e.altKey || e.metaKey){
      return true;
    }

    if(options.allowAny){
      // saves us wiring up a change event as well

      Ember.run.cancel(inputTimeout);
      inputTimeout = Ember.run.later(function(){
        if(inputSelectedItems.length === 0) {
          inputSelectedItems.push("");
        }

        if(_.isString(inputSelectedItems[0]) && me.val().length > 0) {
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
    if ((completeStart === null) && e.which === keys.backSpace && options.key) {
      c = Discourse.Utilities.caretPosition(me[0]);
      c -= 1;
      initial = c;
      prevIsGood = true;
      while (prevIsGood && c >= 0) {
        c -= 1;
        prev = me[0].value[c];
        stopFound = prev === options.key;
        if (stopFound) {
          prev = me[0].value[c - 1];
          if (checkTriggerRule({ backSpace: true }) && (!prev || allowedLettersRegex.test(prev))) {
            completeStart = c;
            caretPosition = completeEnd = initial;
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
      caretPosition = Discourse.Utilities.caretPosition(me[0]);

      // allow people to right arrow out of completion
      if (e.which === keys.rightArrow && me[0].value[caretPosition] === ' ') {
        closeAutocomplete();
        return true;
      }

      // If we've backspaced past the beginning, cancel unless no key
      if (caretPosition <= completeStart && options.key) {
        closeAutocomplete();
        return true;
      }

      // Keyboard codes! So 80's.
      switch (e.which) {
        case keys.enter:
        case keys.tab:
          if (!autocompleteOptions) return true;
          if (selectedOption >= 0 && (userToComplete = autocompleteOptions[selectedOption])) {
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
          completeEnd = caretPosition;
          caretPosition--;

          if (caretPosition < 0) {
            closeAutocomplete();
            if (isInput) {
              i = wrap.find('a:last');
              if (i) {
                i.click();
              }
            }
            return true;
          }

          term = me.val().substring(completeStart + (options.key ? 1 : 0), caretPosition);

          if ((completeStart === caretPosition) && (term === options.key)) {
            closeAutocomplete();
          }

          updateAutoComplete(dataSource(term, options));
          return true;
        default:
          completeEnd = caretPosition;
          return true;
      }
    }
  });

  return this;
}
