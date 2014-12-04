/**
  This view handles rendering of a combobox

  @class ComboboxView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
export default Discourse.View.extend({
  tagName: 'select',
  attributeBindings: ['tabindex'],
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
    if (!Em.isNone(selected)) { selected = selected.toString(); }

    if (this.get('content')) {
      var self = this;
      this.get('content').forEach(function(o) {
        var val = o[self.get('valueAttribute')];
        if (!Em.isNone(val)) { val = val.toString(); }

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

    // Workaround for https://github.com/emberjs/ember.js/issues/9813
    // Can be removed when fixed. Without it, the wrong option is selected
    this.$('option').each(function(i, o) {
      o.selected = !!$(o).attr('selected');
    });

    $elem.select2({formatResult: this.template, minimumResultsForSearch: 5, width: 'resolve'});

    $elem.on("change", function (e) {
      self.set('value', $(e.target).val());
    });
  },

  willClearRender: function() {
    var elementId = "s2id_" + this.$().attr('id');
    Ember.$("#" + elementId).remove();
  }

});
