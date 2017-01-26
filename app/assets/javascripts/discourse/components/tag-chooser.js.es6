import renderTag from 'discourse/lib/render-tag';

function formatTag(t) {
  return renderTag(t.id, {count: t.count, noHref: true});
}

export default Ember.TextField.extend({
  classNameBindings: [':tag-chooser'],
  attributeBindings: ['tabIndex', 'placeholderKey', 'categoryId'],

  init() {
    this._super();
    const tags = this.get('tags') || [];
    this.set('value', tags.join(", "));

    if (this.get('allowCreate') !== false) {
      this.set('allowCreate', this.site.get('can_create_tag'));
    }

    this.set('termMatchesForbidden', false);
  },

  _valueChanged: function() {
    const tags = this.get('value').split(',').map(v => v.trim()).reject(v => v.length === 0).uniq();
    this.set('tags', tags);
  }.observes('value'),

  _tagsChanged: function() {
    const $tagChooser = this.$(),
          val = this.get('value');

    if ($tagChooser && val !== this.get('tags')) {
      if (this.get('tags')) {
        const data = this.get('tags').map((t) => {return {id: t, text: t};});
        $tagChooser.select2('data', data);
      } else {
        $tagChooser.select2('data', []);
      }
    }
  }.observes('tags'),

  didInsertElement() {
    this._super();

    const self = this;
    const filterRegexp = new RegExp(this.site.tags_filter_regexp, "g");

    let limit = this.siteSettings.max_tags_per_topic;

    if (this.get('unlimitedTagCount')) {
      limit = null;
    } else if (this.get('limit')) {
      limit = parseInt(this.get('limit'));
    }

    this.$().select2({
      tags: true,
      placeholder: this.get('placeholder') === "" ? "" : I18n.t(this.get('placeholderKey') || 'tagging.choose_for_topic'),
      maximumInputLength: this.siteSettings.max_tag_length,
      maximumSelectionSize: limit,
      width: this.get('width') || 'resolve',
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
      createSearchChoice(term, data) {
        term = term.replace(filterRegexp, '').trim().toLowerCase();

        // No empty terms, make sure the user has permission to create the tag
        if (!term.length || !self.get('allowCreate') || self.get('termMatchesForbidden')) return;

        if ($(data).filter(function() {
          return this.text.localeCompare(term) === 0;
        }).length === 0) {
          return { id: term, text: term };
        }
      },
      createSearchChoicePosition(list, item) {
        // Search term goes on the bottom
        list.push(item);
      },
      formatSelection(data) {
        return data ? renderTag(this.text(data), {noHref: true}) : undefined;
      },
      formatSelectionCssClass() {
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
          const d = {
            q: term,
            limit: self.siteSettings.max_tag_search_results,
            categoryId: self.get('categoryId'),
            selected_tags: self.get('tags')
          };
          if (!self.get('everyTag')) {
            d.filterForInput = true;
          }
          return d;
        },
        results: function (data) {
          if (self.siteSettings.tags_sort_alphabetically) {
            data.results = data.results.sort(function(a,b) { return a.id > b.id; });
          }
          self.set('termMatchesForbidden', data.forbidden ? true : false);
          return data;
        }
      },
    });
  },

  willDestroyElement() {
    this._super();
    this.$().select2('destroy');
  }

});
