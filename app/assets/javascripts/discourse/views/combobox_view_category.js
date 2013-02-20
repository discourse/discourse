(function() {

  window.Discourse.ComboboxViewCategory = Discourse.ComboboxView.extend({
    none: 'category.none',
    dataAttributes: ['color'],
    template: function(text, templateData) {
      if (!templateData.color) {
        return text;
      }
      return "<span class='badge-category' style='background-color: #" + templateData.color + "'>" + text + "</span>";
    }
  });

}).call(this);
