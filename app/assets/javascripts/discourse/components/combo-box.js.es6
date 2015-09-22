export default Ember.Component.extend({
  tagName: 'select',
  attributeBindings: ['tabindex'],
  classNames: ['combobox'],
  valueAttribute: 'id',
  nameProperty: 'name',

  _buildData(o) {
    let result = "";
    if (this.resultAttributes) {
      this.resultAttributes.forEach(function(a) {
        result += "data-" + a + "=\"" + o.get(a) + "\" ";
      });
    }
    return result;
  },

  render(buffer) {
    const nameProperty = this.get('nameProperty');
    const none = this.get('none');

    // Add none option if required
    if (typeof none === "string") {
      buffer.push('<option value="">' + I18n.t(none) + "</option>");
    } else if (typeof none === "object") {
      buffer.push("<option value=\"\" " + this._buildData(none) + ">" + Em.get(none, nameProperty) + "</option>");
    }

    let selected = this.get('value');
    if (!Em.isNone(selected)) { selected = selected.toString(); }

    if (this.get('content')) {
      const self = this;
      this.get('content').forEach(function(o) {
        let val = o[self.get('valueAttribute')];
        if (typeof val === "undefined") { val = o; }
        if (!Em.isNone(val)) { val = val.toString(); }

        const selectedText = (val === selected) ? "selected" : "";
        const name = Ember.get(o, nameProperty) || o;
        buffer.push("<option " + selectedText + " value=\"" + val + "\" " + self._buildData(o) + ">" + Handlebars.Utils.escapeExpression(name) + "</option>");
      });
    }
  },

  valueChanged: function() {
    const $combo = this.$(),
          val = this.get('value');

    if (val !== undefined && val !== null) {
      $combo.select2('val', val.toString());
    } else {
      $combo.select2('val', null);
    }
  }.observes('value'),

  _rerenderOnChange: function() {
    this.rerender();
  }.observes('content.@each'),

  _initializeCombo: function() {

    // Workaround for https://github.com/emberjs/ember.js/issues/9813
    // Can be removed when fixed. Without it, the wrong option is selected
    this.$('option').each(function(i, o) {
      o.selected = !!$(o).attr('selected');
    });

    // observer for item names changing (optional)
    if (this.get('nameChanges')) {
      this.addObserver('content.@each.' + this.get('nameProperty'), this.rerender);
    }

    const $elem = this.$();
    $elem.select2({formatResult: this.comboTemplate, minimumResultsForSearch: 5, width: 'resolve'});

    const castInteger = this.get('castInteger');
    const self = this;
    $elem.on("change", function (e) {
      let val = $(e.target).val();
      if (val && val.length && castInteger) {
        val = parseInt(val, 10);
      }
      self.set('value', val);
    });
    $elem.trigger('change');
  }.on('didInsertElement'),

  _destroyDropdown: function() {
    this.$().select2('destroy');
  }.on('willDestroyElement')

});
