/**
  This is a jQuery plugin to support autocompleting values in our text fields.

  @module $.fn.autocomplete
**/

var shiftMap = [];
shiftMap[192] = "~";
shiftMap[49] = "!";
shiftMap[50] = "@";
shiftMap[51] = "#";
shiftMap[52] = "$";
shiftMap[53] = "%";
shiftMap[54] = "^";
shiftMap[55] = "&";
shiftMap[56] = "*";
shiftMap[57] = "(";
shiftMap[48] = ")";
shiftMap[109] = "_";
shiftMap[107] = "+";
shiftMap[219] = "{";
shiftMap[221] = "}";
shiftMap[220] = "|";
shiftMap[59] = ":";
shiftMap[222] = "\"";
shiftMap[188] = "<";
shiftMap[190] = ">";
shiftMap[191] = "?";
shiftMap[32] = " ";

function mapKeyPressToActualCharacter(isShiftKey, characterCode) {
  if ( characterCode === 27 || characterCode === 8 || characterCode === 9 || characterCode === 20 || characterCode === 16 || characterCode === 17 || characterCode === 91 || characterCode === 13 || characterCode === 92 || characterCode === 18 ) { return false; }

  if (isShiftKey) {
    if ( characterCode >= 65 && characterCode <= 90 ) {
      return String.fromCharCode(characterCode);
    } else {
      return shiftMap[characterCode];
    }
  } else {
    if ( characterCode >= 65 && characterCode <= 90 ) {
      return String.fromCharCode(characterCode).toLowerCase();
    } else {
      return String.fromCharCode(characterCode);
    }
  }
}

$.fn.autocomplete = function(options) {

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
    autocompleteOptions = null;
  };

  var addInputSelectedItem = function(item) {
    var transformed;
    if (options.transformComplete) {
      transformed = options.transformComplete(item);
    }
    if (options.single){
      // dump what we have in single mode, just in case
      inputSelectedItems = [];
    }
    var d = $("<div class='item'><span>" + (transformed || item) + "<a href='#'><i class='icon-remove'></i></a></span></div>");
    var prev = me.parent().find('.item:last');
    if (prev.length === 0) {
      me.parent().prepend(d);
    } else {
      prev.after(d);
    }
    inputSelectedItems.push(item);
    if (options.onChangeItems) {
      options.onChangeItems(inputSelectedItems);
    }

    d.find('a').click(function() {
      closeAutocomplete();
      inputSelectedItems.splice($.inArray(item, inputSelectedItems), 1);
      $(this).parent().parent().remove();
      if (options.single) {
        me.show();
      }
      if (options.onChangeItems) {
        options.onChangeItems(inputSelectedItems);
      }
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
        text = text.substring(0, completeStart) + (options.key || "") + term + ' ' + text.substring(completeEnd + 1, text.length);
        me.val(text);
        Discourse.Utilities.setCaretPosition(me[0], completeStart + 1 + term.length);
      }
    }
    closeAutocomplete();
  };

  if (isInput) {
    var width = this.width();
    var height = this.height();
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


  $(this).keypress(function(e) {

    if (!options.key) return;

    // keep hunting backwards till you hit a
    if (e.which === options.key.charCodeAt(0)) {
      var caretPosition = Discourse.Utilities.caretPosition(me[0]);
      var prevChar = me.val().charAt(caretPosition - 1);
      if (!prevChar || /\s/.test(prevChar)) {
        completeStart = completeEnd = caretPosition;
        var term = "";
        options.dataSource(term).then(updateAutoComplete);
      }
    }
  });

  return $(this).keydown(function(e) {
    var c, caretPosition, i, initial, next, nextIsGood, prev, prevIsGood, stopFound, term, total, userToComplete;

    if(options.allowAny){
      // saves us wiring up a change event as well, keypress is while its pressed
      _.delay(function(){
        if(inputSelectedItems.length === 0) {
          inputSelectedItems.push("");
        }

        if(_.isString(inputSelectedItems[0])) {
          inputSelectedItems.pop();
          inputSelectedItems.push(me.val());
          if (options.onChangeItems) {
            options.onChangeItems(inputSelectedItems);
          }
        }

      },50);
    }

    if (!options.key) {
      completeStart = 0;
    }
    if (e.which === 16) return;
    if ((completeStart === null) && e.which === 8 && options.key) {
      c = Discourse.Utilities.caretPosition(me[0]);
      next = me[0].value[c];
      nextIsGood = next === void 0 || /\s/.test(next);
      c -= 1;
      initial = c;
      prevIsGood = true;
      while (prevIsGood && c >= 0) {
        c -= 1;
        prev = me[0].value[c];
        stopFound = prev === options.key;
        if (stopFound) {
          prev = me[0].value[c - 1];
          if (!prev || /\s/.test(prev)) {
            completeStart = c;
            caretPosition = completeEnd = initial;
            term = me[0].value.substring(c + 1, initial);
            options.dataSource(term).then(updateAutoComplete);
            return true;
          }
        }
        prevIsGood = /[a-zA-Z\.]/.test(prev);
      }
    }

    // ESC
    if (e.which === 27) {
      if (completeStart !== null) {
        closeAutocomplete();
        return false;
      }
      return true;
    }

    if (completeStart !== null) {
      caretPosition = Discourse.Utilities.caretPosition(me[0]);

      // If we've backspaced past the beginning, cancel unless no key
      if (caretPosition <= completeStart && options.key) {
        closeAutocomplete();
        return false;
      }

      // Keyboard codes! So 80's.
      switch (e.which) {
        case 13:
        case 39:
        case 9:
          if (!autocompleteOptions) return true;
          if (selectedOption >= 0 && (userToComplete = autocompleteOptions[selectedOption])) {
            completeTerm(userToComplete);
          } else {
            // We're cancelling it, really.
            return true;
          }
          e.stopImmediatePropagation();
          return false;
        case 38:
          selectedOption = selectedOption - 1;
          if (selectedOption < 0) {
            selectedOption = 0;
          }
          markSelected();
          return false;
        case 40:
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
        default:
          // otherwise they're typing - let's search for it!
          completeEnd = caretPosition;
          if (e.which === 8) {
            caretPosition--;
          }
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
          term = me.val().substring(completeStart + (options.key ? 1 : 0), caretPosition);
          if (e.which >= 48 && e.which <= 90) {
            term += mapKeyPressToActualCharacter(e.shiftKey, e.which);
          } else if (e.which === 187) {
            term += "+";
          } else if (e.which === 189) {
            term += (e.shiftKey) ? "_" : "-";
          } else if (e.which === 220) {
            term += (e.shiftKey) ? "|" : "]";
          } else if (e.which === 222) {
            term += (e.shiftKey) ? "\"" : "'";
          } else {
            if (e.which !== 8) {
              term += ",";
            }
          }

          options.dataSource(term).then(updateAutoComplete);
          return true;
      }
    }
  });
};
