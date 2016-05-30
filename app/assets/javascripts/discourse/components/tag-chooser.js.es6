import renderTag from 'discourse/lib/render-tag';

function formatTag(t) {
  return renderTag(t.id, {count: t.count});
}

export default Ember.TextField.extend({
  classNameBindings: [':tag-chooser'],
  attributeBindings: ['tabIndex', 'placeholderKey', 'categoryId'],

  _setupTags: function() {
    const tags = this.get('tags') || [];
    this.set('value', tags.join(", "));
  }.on('init'),

  _valueChanged: function() {
    const tags = this.get('value').split(',').map(v => v.trim()).reject(v => v.length === 0).uniq();
    this.set('tags', tags);
  }.observes('value'),

  _initializeTags: function() {
    const site = this.site,
          self = this,
          filterRegexp = new RegExp(this.site.tags_filter_regexp, "g");

    this.$().select2({
      tags: true,
      placeholder: I18n.t(this.get('placeholderKey') || 'tagging.choose_for_topic'),
      maximumInputLength: this.siteSettings.max_tag_length,
      maximumSelectionSize: this.siteSettings.max_tags_per_topic,
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
          data.push({
            id: this,
            text: this
          });
        });

        callback(data);
      },
      createSearchChoice: function(term, data) {
        term = term.replace(filterRegexp, '').trim();

        // No empty terms, make sure the user has permission to create the tag
        if (!term.length || !site.get('can_create_tag')) { return; }

        if ($(data).filter(function() {
          return this.text.localeCompare(term) === 0;
        }).length === 0) {
          return { id: term, text: term };
        }
      },
      createSearchChoicePosition: function(list, item) {
        // Search term goes on the bottom
        list.push(item);
      },
      formatSelection: function (data) {
          return data ? renderTag(this.text(data)) : undefined;
      },
      formatSelectionCssClass: function(){
        return "discourse-tag-select2";
      },
      formatResult: formatTag,
      multiple: true,
      ajax: {
        quietMillis: 200,
        cache: true,
        url: Discourse.getURL("/tags/filter/search"),
        dataType: 'json',
        data: function (term) {
          return { q: term, limit: self.siteSettings.max_tag_search_results, filterForInput: true, categoryId: self.get('categoryId') };
        },
        results: function (data) {
          if (self.siteSettings.tags_sort_alphabetically) {
            data.results = data.results.sort(function(a,b) { return a.id > b.id; });
          }
          return data;
        }
      },
    });
  }.on('didInsertElement'),

  _destroyTags: function() {
    this.$().select2('destroy');
  }.on('willDestroyElement')

});
