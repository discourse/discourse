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

    // Add none option if required
    if (this.get('none')) {
      buffer.push("<option value=\"\">" + (Ember.String.i18n(this.get('none'))) + "</option>");
    }

    var selected = this.get('value');
    if (selected) { selected = selected.toString(); }

    if (this.get('content')) {

      var comboboxView = this;
      this.get('content').each(function(o) {
        var val = o[comboboxView.get('valueAttribute')];
        if (val) { val = val.toString(); }

        var selectedText = (val === selected) ? "selected" : "";

        var data = "";
        if (comboboxView.dataAttributes) {
          comboboxView.dataAttributes.forEach(function(a) {
            data += "data-" + a + "=\"" + (o.get(a)) + "\" ";
          });
        }
        buffer.push("<option " + selectedText + " value=\"" + val + "\" " + data + ">" + o.name + "</option>");
      });
    }
  },

  valueChanged: function() {
    var $combo = this.$();
    var val = this.get('value');
    if (val !== undefined && val !== null) {
      $combo.val(val.toString());
    } else {
      $combo.val(null);
    }
    $combo.trigger("liszt:updated");
  }.observes('value'),

  didInsertElement: function() {
    var $elem = this.$();
    var comboboxView = this;

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
      this.classNames.each(function(c) {
        $elem.chosen().next().addClass(c);
      });
    }

    $elem.chosen().change(function(e) {
      comboboxView.set('value', $(e.target).val());
    });
  }

});

Discourse.View.registerHelper('combobox', Discourse.ComboboxView);