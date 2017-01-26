function renderTagGroup(tag) {
  return "<a class='discourse-tag'>" + Handlebars.Utils.escapeExpression(tag.text ? tag.text : tag) + "</a>";
};

export default Ember.TextField.extend({
  classNameBindings: [':tag-chooser'],
  attributeBindings: ['tabIndex', 'placeholderKey', 'categoryId'],

  _initValue: function() {
    const names = this.get('tagGroups') || [];
    this.set('value', names.join(","));
  }.on('init'),

  _valueChanged: function() {
    const names = this.get('value').split(',').map(v => v.trim()).reject(v => v.length === 0).uniq();
    if ( this.get('tagGroups').join(',') !== this.get('value') ) {
      this.set('tagGroups', names);
    }
  }.observes('value'),

  _tagGroupsChanged: function() {
    const $chooser = this.$(),
          val = this.get('value');

    if ($chooser && val !== this.get('tagGroups')) {
      if (this.get('tagGroups')) {
        const data = this.get('tagGroups').map((t) => {return {id: t, text: t};});
        $chooser.select2('data', data);
      } else {
        $chooser.select2('data', []);
      }
    }
  }.observes('tagGroups'),

  _initializeChooser: function() {
    const self = this;

    this.$().select2({
      tags: true,
      placeholder: this.get('placeholderKey') ? I18n.t(this.get('placeholderKey')) : null,
      initSelection(element, callback) {
        const data = [];

        function splitVal(string, separator) {
          var val, i, l;
          if (string === null || string.length < 1) return [];
          val = string.split(separator);
          for (i = 0, l = val.length; i < l; i = i + 1) val[i] = $.trim(val[i]);
          return val;
        }

        $(splitVal(element.val(), ",")).each(function () {
          data.push({ id: this, text: this });
        });

        callback(data);
      },
      formatSelection: function (data) {
        return data ? renderTagGroup(this.text(data)) : undefined;
      },
      formatSelectionCssClass: function(){
        return "discourse-tag-select2";
      },
      formatResult: renderTagGroup,
      multiple: true,
      ajax: {
        quietMillis: 200,
        cache: true,
        url: Discourse.getURL("/tag_groups/filter/search"),
        dataType: 'json',
        data: function (term) {
          return { q: term, limit: self.siteSettings.max_tag_search_results };
        },
        results: function (data) {
          data.results = data.results.sort(function(a,b) { return a.text > b.text; });
          return data;
        }
      },
    });
  }.on('didInsertElement'),

  _destroyChooser: function() {
    this.$().select2('destroy');
  }.on('willDestroyElement')

});
