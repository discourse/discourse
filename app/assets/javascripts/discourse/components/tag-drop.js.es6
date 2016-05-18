import { setting } from 'discourse/lib/computed';

export default Ember.Component.extend({
  classNameBindings: [':tag-drop', 'tag::no-category', 'tags:has-drop','categoryStyle','tagClass'],
  categoryStyle: setting('category_style'), // match the category-drop style
  currentCategory: Em.computed.or('secondCategory', 'firstCategory'),
  showFilterByTag: setting('show_filter_by_tag'),
  showTagDropdown: Em.computed.and('showFilterByTag', 'tags'),
  tagId: null,

  tagName: 'li',

  tags: function() {
    if (this.siteSettings.tags_sort_alphabetically && Discourse.Site.currentProp('top_tags')) {
      return Discourse.Site.currentProp('top_tags').sort();
    } else {
      return Discourse.Site.currentProp('top_tags');
    }
  }.property('site.top_tags'),

  iconClass: function() {
    if (this.get('expanded')) { return "fa fa-caret-down"; }
    return "fa fa-caret-right";
  }.property('expanded'),

  tagClass: function() {
    if (this.get('tagId')) {
      return "tag-" + this.get('tagId');
    } else {
      return "tag_all";
    }
  }.property('tagId'),

  allTagsUrl: function() {
    if (this.get('currentCategory')) {
      return this.get('currentCategory.url') + "?allTags=1";
    } else {
      return "/";
    }
  }.property('firstCategory', 'secondCategory'),

  allTagsLabel: function() {
    return I18n.t("tagging.selector_all_tags");
  }.property('tag'),

  dropdownButtonClass: function() {
    var result = 'badge-category category-dropdown-button';
    if (Em.isNone(this.get('tag'))) {
      result += ' home';
    }
    return result;
  }.property('tag'),

  clickEventName: function() {
    return "click.tag-drop-" + (this.get('tag') || "all");
  }.property('tag'),

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
