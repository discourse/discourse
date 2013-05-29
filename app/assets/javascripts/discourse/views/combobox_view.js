/**
  This view handles rendering of a combobox

  @class ComboboxView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.ComboboxView = Discourse.View.extend({
  tagName: 'select',
  classNames: ['combobox'],
  valueAttribute: 'id',

  render: function(buffer) {
    var _ref,
      _this = this;

    // Add none option if required
    if (this.get('none')) {
      buffer.push("<option value=\"\">" + (Ember.String.i18n(this.get('none'))) + "</option>");
    }

    var selected = (_ref = this.get('value')) ? _ref.toString() : void 0;

    if (this.get('content')) {
      return this.get('content').each(function(o) {
        var data, selectedText, val, _ref1;
        val = (_ref1 = o[_this.get('valueAttribute')]) ? _ref1.toString() : void 0;
        selectedText = val === selected ? "selected" : "";
        data = "";
        if (_this.dataAttributes) {
          _this.dataAttributes.forEach(function(a) {
            data += "data-" + a + "=\"" + (o.get(a)) + "\" ";
          });
        }
        return buffer.push("<option " + selectedText + " value=\"" + val + "\" " + data + ">" + o.name + "</option>");
      });
    }
  },

  valueChanged: function() {
    var $combo = this.$();
    var val = this.get('value');
    if (val) {
      $combo.val(this.get('value').toString());
    } else {
      $combo.val(null);
    }
    $combo.trigger("liszt:updated")
  }.observes('value'),

  didInsertElement: function() {
    var $elem,
      _this = this;
    $elem = this.$();
    $elem.chosen({ template: this.template, disable_search_threshold: 5 });
    if (this.overrideWidths) {
      // The Chosen plugin hard-codes the widths in style attrs. :<
      var $chznContainer = $elem.chosen().next();
      $chznContainer.removeAttr("style");
      $chznContainer.find('.chzn-drop').removeAttr("style");
      $chznContainer.find('.chzn-search input').removeAttr("style");
    }
    if (this.classNames && this.classNames.length > 0) {
      // Apply the classes to Chosen's dropdown div too:
      this.classNames.each( function(c) {
        $elem.chosen().next().addClass(c);
      });
    }

    $elem.change(function(e) {
      _this.set('value', $(e.target).val());
    });
  }

});

Discourse.View.registerHelper('combobox', Discourse.ComboboxView);