import { on, observes } from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  tagName: 'select',
  attributeBindings: ['tabindex'],
  classNames: ['combobox'],
  valueAttribute: 'id',
  nameProperty: 'name',

  render(buffer) {
    const nameProperty = this.get('nameProperty');
    const none = this.get('none');

    // Add none option if required
    if (typeof none === "string") {
      buffer.push('<option value="">' + I18n.t(none) + "</option>");
    } else if (typeof none === "object") {
      buffer.push("<option value=\"\">" + Em.get(none, nameProperty) + "</option>");
    }

    let selected = this.get('value');
    if (!Em.isNone(selected)) { selected = selected.toString(); }

    if (this.get('content')) {
      this.get('content').forEach(o => {
        let val = o[this.get('valueAttribute')];
        if (typeof val === "undefined") { val = o; }
        if (!Em.isNone(val)) { val = val.toString(); }

        const selectedText = (val === selected) ? "selected" : "";
        const name = Handlebars.Utils.escapeExpression(Ember.get(o, nameProperty) || o);
        buffer.push(`<option ${selectedText} value="${val}">${name}</option>`);
      });
    }
  },

  @observes('value')
  valueChanged() {
    const $combo = this.$(),
          val = this.get('value');

    if (val !== undefined && val !== null) {
      $combo.select2('val', val.toString());
    } else {
      $combo.select2('val', null);
    }
  },

  @observes('content.[]')
  _rerenderOnChange() {
    this.rerender();
  },

  @on('didInsertElement')
  _initializeCombo() {

    // Workaround for https://github.com/emberjs/ember.js/issues/9813
    // Can be removed when fixed. Without it, the wrong option is selected
    this.$('option').each((i, o) => o.selected = !!$(o).attr('selected'));

    // observer for item names changing (optional)
    if (this.get('nameChanges')) {
      this.addObserver('content.@each.' + this.get('nameProperty'), this.rerender);
    }

    const $elem = this.$();
    const minimumResultsForSearch = this.capabilities.isIOS ? -1 : 5;
    $elem.select2({
      formatResult: this.comboTemplate, minimumResultsForSearch,
      width: 'resolve',
      allowClear: true
    });

    const castInteger = this.get('castInteger');
    $elem.on("change", e => {
      let val = $(e.target).val();
      if (val && val.length && castInteger) {
        val = parseInt(val, 10);
      }
      this.set('value', val);
    });
    $elem.trigger('change');
  },

  @on('willDestroyElement')
  _destroyDropdown() {
    this.$().select2('destroy');
  }

});
