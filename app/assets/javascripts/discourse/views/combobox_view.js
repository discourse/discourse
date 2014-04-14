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

  buildData: function(o) {
    var data = "";
    if (this.dataAttributes) {
      this.dataAttributes.forEach(function(a) {
        data += "data-" + a + "=\"" + o.get(a) + "\" ";
      });
    }
    return data;
  },

  render: function(buffer) {
    var nameProperty = this.get('nameProperty') || 'name',
        none = this.get('none');

    // Add none option if required
    if (typeof none === "string") {
      buffer.push('<option value="">' + I18n.t(none) + "</option>");
    } else if (typeof none === "object") {
      buffer.push("<option value=\"\" " + this.buildData(none) + ">" + Em.get(none, nameProperty) + "</option>");
    }

    var selected = this.get('value');
    if (selected) { selected = selected.toString(); }

    if (this.get('content')) {
      var self = this;
      this.get('content').forEach(function(o) {
        var val = o[self.get('valueAttribute')];
        if (val) { val = val.toString(); }

        var selectedText = (val === selected) ? "selected" : "";
        buffer.push("<option " + selectedText + " value=\"" + val + "\" " + self.buildData(o) + ">" + Handlebars.Utils.escapeExpression(Em.get(o, nameProperty)) + "</option>");
      });
    }
  },

  valueChanged: function() {
    var $combo = this.$(),
        val = this.get('value');
    if (val !== undefined && val !== null) {
      $combo.val(val.toString());
    } else {
      $combo.val(null);
    }
    $combo.trigger("liszt:updated");
  }.observes('value'),

  contentChanged: function() {
    this.rerender();
  }.observes('content.@each'),

  didInsertElement: function() {
    var $elem = this.$(),
        self = this;

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
      _.each(this.classNames,function(c) {
        $elem.chosen().next().addClass(c);
      });
    }

    $elem.chosen().change(function(e) {
      self.set('value', $(e.target).val());
    });
  },

  willClearRender: function() {
    var chosenId = this.$().attr('id') + "_chzn";
    Ember.$("#" + chosenId).remove();
  }

});

Discourse.View.registerHelper('combobox', Discourse.ComboboxView);
