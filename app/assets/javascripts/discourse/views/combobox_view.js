(function() {

  Discourse.ComboboxView = window.Ember.View.extend({
    tagName: 'select',
    classNames: ['combobox'],
    valueAttribute: 'id',
    render: function(buffer) {
      var selected, _ref,
        _this = this;
      if (this.get('none')) {
        buffer.push("<option value=\"\">" + (Ember.String.i18n(this.get('none'))) + "</option>");
      }
      selected = (_ref = this.get('value')) ? _ref.toString() : void 0;
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
    didInsertElement: function() {
      var $elem,
        _this = this;
      $elem = this.$();
      $elem.chosen({
        template: this.template,
        disable_search_threshold: 5
      });
      return $elem.change(function(e) {
        return _this.set('value', jQuery(e.target).val());
      });
    }
  });

}).call(this);
