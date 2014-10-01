/**
  This is a jQuery plugin to support autocompleting values in our text fields.

  @module $.fn.autocomplete
**/

export var CANCELLED_STATUS = "__CANCELLED";

var Keys = {
  BackSpace: 8,
  Tab: 9,
  Enter: 13,
  Shift: 16,
  Ctrl: 17,
  Alt: 18,
  Esc: 27,
  Space: 32,
  LeftWindows: 91,
  RightWindows: 92,
  PageUp: 33,
  PageDown: 34,
  End: 35,
  Home: 36,
  LeftArrow: 37,
  UpArrow: 38,
  RightArrow: 39,
  DownArrow: 40,
};

export default function(options) {
  var autocompletePlugin = this;

  if (this.length === 0) return;

  if (options && options.cancel && this.data("closeAutocomplete")) {
    this.data("closeAutocomplete")();
    return this;
  }

  if (this.length !== 1) {
    alert("only supporting one matcher at the moment");
  }

  var disabled = options && options.disabled;
  var wrap = null;
  var autocompleteOptions = null;
  var selectedOption = null;
  var completeStart = null;
  var completeEnd = null;
  var me = this;
  var div = null;

  // input is handled differently
  var isInput = this[0].tagName === "INPUT";
  var inputSelectedItems = [];

  var closeAutocomplete = function() {
    if (div) {
      div.hide().remove();
    }
    div = null;
    completeStart = null;
    completeEnd = null;
    autocompleteOptions = null;
  };

  var autoCompleting = function () {
    return completeStart !== null;
  };

  var addInputSelectedItem = function(item) {
    var transformed,
        transformedItem = item;

    if (options.transformComplete) { transformedItem = options.transformComplete(transformedItem); }
    // dump what we have in single mode, just in case
    if (options.single) { inputSelectedItems = []; }
    transformed = _.isArray(transformedItem) ? transformedItem : [transformedItem || item];

    var divs = transformed.map(function(itm) {
      var d = $("<div class='item'><span>" + itm + "<a class='remove' href='#'><i class='fa fa-times'></i></a></span></div>");
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
        var text = me.val();
        text = text.substring(0, completeStart) + term + ' ' + text.substring(completeEnd, text.length);
        me.val(text);
        Discourse.Utilities.setCaretPosition(me[0], completeStart + 1 + term.length);
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

    var mePos = me.position();
    var borderTop = parseInt(me.css('border-top-width'), 10) || 0;
    div.css({
      position: 'absolute',
      top: (mePos.top + pos.top - vOffset + borderTop) + 'px',
      left: (mePos.left + pos.left + hOffset) + 'px'
    });
  };

  var updateAutoComplete = function(r) {

    if (completeStart === null) return;

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

  var getTerm = function() {
    return me.val().slice(completeStart, completeEnd);
  };

  $(this).keypress(function(e) {
    var term, key = (e.char || String.fromCharCode(e.charCode));

    // if we just started with an options.key, set start and end.
    if (key === options.key && !autoCompleting()) {
      completeStart = completeEnd = Discourse.Utilities.caretPosition(me[0]) + 1;
    }

    if (!options.key) {
      completeStart = 0;
      completeEnd = Discourse.Utilities.caretPosition(me[0]);
    }

    if (autoCompleting()) {
      if ((completeStart === completeEnd) && key === options.key) {
        updateAutoComplete(options.dataSource(""));
      } else {
        term = getTerm() + key;
        completeEnd += 1;
        updateAutoComplete(options.dataSource(term));
      }
      return true;
    }
  });

  $(this).keydown(function(e) {
    var caretPosition, i, term, total, userToComplete;

    if(options.allowAny){
      // saves us wiring up a change event as well, keypress is while its pressed
      _.delay(function(){
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

      },50);
    }

    // Handle Backspacing into stuff
    if ((!autoCompleting()) && e.which === Keys.BackSpace && options.key) {
      var c = Discourse.Utilities.caretPosition(me[0]),
          last, first,
          text = me[0].value;
      // search backwards until you find the last letter of the word
      while (/[\s]/.test(text[c]) && c >= 0) { c--; }
      last = c;
      // search further until you find the first letter of the word
      while (/[\S]/.test(text[c]) && c >= 0) { c--; }
      first = c + 1;

      if (text[first] === options.key) {
        completeStart = first + 1;
        completeEnd = (options.key === ":" ? last - 1 : last);

        if (completeEnd >= completeStart) {
          updateAutoComplete(options.dataSource(getTerm()));
        }
        return true;
      }
    }

    if (autoCompleting()) {
      // Keyboard codes! So 80's.
      switch (e.which) {
        case Keys.Esc:
          closeAutocomplete();
          return false;
        case Keys.Enter:
        case Keys.RightArrow:
        case Keys.Tab:
          if (!autocompleteOptions) return true;
          if (selectedOption >= 0 && (userToComplete = autocompleteOptions[selectedOption])) {
            completeTerm(userToComplete);
          } else {
            // We're cancelling it, really.
            return true;
          }
          e.stopImmediatePropagation();
          return false;
        case Keys.UpArrow:
          selectedOption = selectedOption - 1;
          if (selectedOption < 0) {
            selectedOption = 0;
          }
          markSelected();
          return false;
        case Keys.DownArrow:
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
        case Keys.BackSpace:
          caretPosition = Discourse.Utilities.caretPosition(me[0]) - 1;
          completeEnd = caretPosition;


          if (caretPosition < 0) {
            closeAutocomplete();
            if (isInput) {
              i = wrap.find('a:last');
              if (i) {
                i.click();
              }
            }
            return false;
          }

          if (completeEnd < completeStart) {
            closeAutocomplete();
            return true;
          }

          term = getTerm();
          updateAutoComplete(options.dataSource(term));
          return true;
        default:
          return true;
      }
    }
  });

  return this;
}
