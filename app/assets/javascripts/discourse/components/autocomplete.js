(function() {

  (function($) {
    var template;
    template = null;
    $.fn.autocomplete = function(options) {
      var addInputSelectedItem, autocompleteOptions, closeAutocomplete, completeEnd, completeStart, completeTerm, div, height;
      var inputSelectedItems, isInput, markSelected, me, oldClose, renderAutocomplete, selectedOption, updateAutoComplete, vals;
      var width, wrap, _this = this;
      if (this.length === 0) {
        return;
      }
      if (options && options.cancel && this.data("closeAutocomplete")) {
        this.data("closeAutocomplete")();
        return this;
      }
      if (this.length !== 1) {
        alert("only supporting one matcher at the moment");
      }
      autocompleteOptions = null;
      selectedOption = null;
      completeStart = null;
      completeEnd = null;
      me = this;
      div = null;
      /* input is handled differently
      */

      isInput = this[0].tagName === "INPUT";
      inputSelectedItems = [];
      addInputSelectedItem = function(item) {
        var d, prev, transformed;
        if (options.transformComplete) {
          transformed = options.transformComplete(item);
        }
        d = jQuery("<div class='item'><span>" + (transformed || item) + "<a href='#'><i class='icon-remove'></i></a></span></div>");
        prev = me.parent().find('.item:last');
        if (prev.length === 0) {
          me.parent().prepend(d);
        } else {
          prev.after(d);
        }
        inputSelectedItems.push(item);
        if (options.onChangeItems) {
          options.onChangeItems(inputSelectedItems);
        }
        return d.find('a').click(function() {
          closeAutocomplete();
          inputSelectedItems.splice(jQuery.inArray(item), 1);
          jQuery(this).parent().parent().remove();
          if (options.onChangeItems) {
            return options.onChangeItems(inputSelectedItems);
          }
        });
      };
      if (isInput) {
        width = this.width();
        height = this.height();
        wrap = this.wrap("<div class='ac-wrap clearfix'/>").parent();
        wrap.width(width);
        this.width(80);
        this.attr('name', this.attr('name') + "-renamed");
        vals = this.val().split(",");
        vals.each(function(x) {
          if (x !== "") {
            if (options.reverseTransform) {
              x = options.reverseTransform(x);
            }
            return addInputSelectedItem(x);
          }
        });
        this.val("");
        completeStart = 0;
        wrap.click(function() {
          _this.focus();
          return true;
        });
      }
      markSelected = function() {
        var links;
        links = div.find('li a');
        links.removeClass('selected');
        return jQuery(links[selectedOption]).addClass('selected');
      };
      renderAutocomplete = function() {
        var borderTop, mePos, pos, ul;
        if (div) {
          div.hide().remove();
        }
        if (autocompleteOptions.length === 0) {
          return;
        }
        div = jQuery(options.template({
          options: autocompleteOptions
        }));
        ul = div.find('ul');
        selectedOption = 0;
        markSelected();
        ul.find('li').click(function() {
          selectedOption = ul.find('li').index(this);
          completeTerm(autocompleteOptions[selectedOption]);
          return false;
        });
        pos = null;
        if (isInput) {
          pos = {
            left: 0,
            top: 0
          };
        } else {
          pos = me.caretPosition({
            pos: completeStart,
            key: options.key
          });
        }
        div.css({
          left: "-1000px"
        });
        me.parent().append(div);
        mePos = me.position();
        borderTop = parseInt(me.css('border-top-width'), 10) || 0;
        return div.css({
          position: 'absolute',
          top: (mePos.top + pos.top - div.height() + borderTop) + 'px',
          left: (mePos.left + pos.left + 27) + 'px'
        });
      };
      updateAutoComplete = function(r) {
        if (!completeStart) return;
        
        autocompleteOptions = r;
        if (!r || r.length === 0) {
          return closeAutocomplete();
        } else {
          return renderAutocomplete();
        }
      };
      closeAutocomplete = function() {
        if (div) {
          div.hide().remove();
        }
        div = null;
        completeStart = null;
        autocompleteOptions = null;
      };
      /* chain to allow multiples
      */

      oldClose = me.data("closeAutocomplete");
      me.data("closeAutocomplete", function() {
        if (oldClose) {
          oldClose();
        }
        return closeAutocomplete();
      });
      completeTerm = function(term) {
        var text;
        if (term) {
          if (isInput) {
            me.val("");
            addInputSelectedItem(term);
          } else {
            if (options.transformComplete) {
              term = options.transformComplete(term);
            }
            text = me.val();
            text = text.substring(0, completeStart) + (options.key || "") + term + ' ' + text.substring(completeEnd + 1, text.length);
            me.val(text);
            Discourse.Utilities.setCaretPosition(me[0], completeStart + 1 + term.length);
          }
        }
        return closeAutocomplete();
      };
      jQuery(this).keypress(function(e) {
        var caretPosition, prevChar, term;
        if (!options.key) {
          return;
        }
        /* keep hunting backwards till you hit a
        */

        if (e.which === options.key.charCodeAt(0)) {
          caretPosition = Discourse.Utilities.caretPosition(me[0]);
          prevChar = me.val().charAt(caretPosition - 1);
          if (!prevChar || /\s/.test(prevChar)) {
            completeStart = completeEnd = caretPosition;
            term = "";
            options.dataSource(term, updateAutoComplete);
          }
        }
      });
      return jQuery(this).keydown(function(e) {
        var c, caretPosition, i, initial, next, nextIsGood, prev, prevIsGood, stopFound, term, total, userToComplete;
        if (!options.key) {
          completeStart = 0;
        }
        if (e.which === 16) {
          return;
        }
        if ((!completeStart) && e.which === 8 && options.key) {
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
                options.dataSource(term, updateAutoComplete);
                return true;
              }
            }
            prevIsGood = /[a-zA-Z\.]/.test(prev);
          }
        }
        if (e.which === 27) {
          if (completeStart) {
            closeAutocomplete();
            return false;
          }
          return true;
        }
        if (completeStart) {
          caretPosition = Discourse.Utilities.caretPosition(me[0]);
          /* If we've backspaced past the beginning, cancel unless no key
          */

          if (caretPosition <= completeStart && options.key) {
            closeAutocomplete();
            return false;
          }
          /* Keyboard codes! So 80's.
          */

          switch (e.which) {
            case 13:
            case 39:
            case 9:
              if (!autocompleteOptions) {
                return true;
              }
              if (selectedOption >= 0 && (userToComplete = autocompleteOptions[selectedOption])) {
                completeTerm(userToComplete);
              } else {
                /* We're cancelling it, really.
                */

                return true;
              }
              closeAutocomplete();
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
              /* otherwise they're typing - let's search for it!
              */

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
              if (e.which > 48 && e.which < 90) {
                term += String.fromCharCode(e.which);
              } else {
                if (e.which !== 8) {
                  term += ",";
                }
              }
              options.dataSource(term, updateAutoComplete);
              return true;
          }
        }
      });
    };
    return $.fn.autocomplete;
  })(jQuery);

}).call(this);
