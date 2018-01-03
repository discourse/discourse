import { setting } from 'discourse/lib/computed';
import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  classNameBindings: [':tag-drop', 'tag::no-category', 'tags:has-drop','categoryStyle','tagClass'],
  categoryStyle: setting('category_style'), // match the category-drop style
  currentCategory: Em.computed.or('secondCategory', 'firstCategory'),
  showFilterByTag: setting('show_filter_by_tag'),
  showTagDropdown: Em.computed.and('showFilterByTag', 'tags'),
  tagId: null,

  tagName: 'li',

  @computed('site.top_tags')
  tags(topTags) {
    if (this.siteSettings.tags_sort_alphabetically && topTags) {
      return topTags.sort();
    } else {
      return topTags;
    }
  },

  @computed('expanded')
  expandedIcon(expanded) {
    return expanded ? 'd-drop-expanded' : 'd-drop-collapsed';
  },

  @computed('tagId')
  tagClass() {
    if (this.get('tagId')) {
      return "tag-" + this.get('tagId');
    } else {
      return "tag_all";
    }
  },

  @computed('firstCategory', 'secondCategory')
  allTagsUrl() {
    if (this.get('currentCategory')) {
      return this.get('currentCategory.url') + "?allTags=1";
    } else {
      return "/";
    }
  },

  @computed('tag')
  allTagsLabel() {
    return I18n.t("tagging.selector_all_tags");
  },

  @computed('tagId')
  noTagsSelected() {
    return this.get('tagId') === 'none';
  },

  @computed('firstCategory', 'secondCategory')
  noTagsUrl() {
    var url = '/tags';
    if (this.get('currentCategory')) {
      url += this.get('currentCategory.url');
    }
    return url + '/none';
  },

  @computed('tag')
  noTagsLabel() {
    return I18n.t("tagging.selector_no_tags");
  },

  @computed('tag')
  dropdownButtonClass() {
    let result = 'dropdown-header category-dropdown-button';
    if (Em.isNone(this.get('tag'))) {
      result += ' home';
    }
    return result;
  },

  @computed('tag')
  clickEventName() {
    return "click.tag-drop-" + (this.get('tag') || "all");
  },

  actions: {
    expand: function() {
      var self = this;

      if(!this.get('renderTags')){
        this.set('renderTags',true);
        Em.run.next(function(){
          self.send('expand');
        });
        return;
      }

      if (this.get('expanded')) {
        this.close();
        return;
      }

      if (this.get('tags')) {
        this.set('expanded', true);
      }
      var $dropdown = this.$()[0];

      this.$('a[data-drop-close]').on('click.tag-drop', function() {
        self.close();
      });

      Em.run.next(function(){
        self.$('.cat a').add('html').on(self.get('clickEventName'), function(e) {
          var $target = $(e.target),
              closest = $target.closest($dropdown);

          if ($(e.currentTarget).hasClass('badge-wrapper')){
            self.close();
          }

          return ($(e.currentTarget).hasClass('badge-category') || (closest.length && closest[0] === $dropdown)) ? true : self.close();
        });
      });
    }
  },

  removeEvents: function(){
    $('html').off(this.get('clickEventName'));
    this.$('a[data-drop-close]').off('click.tag-drop');
  },

  close: function() {
    this.removeEvents();
    this.set('expanded', false);
  },

  willDestroyElement: function() {
    this.removeEvents();
  }

});
