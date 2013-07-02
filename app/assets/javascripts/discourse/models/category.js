/**
  A data model that represents a category

  @class Category
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.Category = Discourse.Model.extend({

  init: function() {
    this._super();
    this.set("availableGroups", Em.A(this.get("available_groups")));
    this.set("groups", Em.A(this.groups));
  },

  searchContext: function() {
    return ({ type: 'category', id: this.get('id'), category: this });
  }.property('id'),

  url: function() {
    return Discourse.getURL("/category/") + (this.get('slug'));
  }.property('name'),

  style: function() {
    return "background-color: #" + (this.get('category.color')) + "; color: #" + (this.get('category.text_color')) + ";";
  }.property('color', 'text_color'),

  moreTopics: function() {
    return this.get('topic_count') > Discourse.SiteSettings.category_featured_topics;
  }.property('topic_count'),

  save: function(args) {
    var url = "/categories";
    if (this.get('id')) {
      url = "/categories/" + (this.get('id'));
    }

    return Discourse.ajax(url, {
      data: {
        name: this.get('name'),
        color: this.get('color'),
        text_color: this.get('text_color'),
        hotness: this.get('hotness'),
        secure: this.get('secure'),
        group_names: this.get('groups').join(","),
        auto_close_days: this.get('auto_close_days')
      },
      type: this.get('id') ? 'PUT' : 'POST'
    });
  },

  destroy: function(callback) {
    return Discourse.ajax("/categories/" + (this.get('slug') || this.get('id')), { type: 'DELETE' });
  },

  addGroup: function(group){
    this.get("groups").addObject(group);
    this.get("availableGroups").removeObject(group);
  },


  removeGroup: function(group){
    this.get("groups").removeObject(group);
    this.get("availableGroups").addObject(group);
  },

  // note, this is used in a data attribute, data attributes get downcased
  //  to avoid confusion later on using this naming here.
  description_text: function(){
    return $("<div>" + this.get("description") + "</div>").text();
  }.property("description")

});

Discourse.Category.reopenClass({

  uncategorizedInstance: function() {
    if (this.uncategorized) return this.uncategorized;

    this.uncategorized = this.create({
      slug: 'uncategorized',
      name: Discourse.SiteSettings.uncategorized_name,
      isUncategorized: true,
      color: Discourse.SiteSettings.uncategorized_color,
      text_color: Discourse.SiteSettings.uncategorized_text_color
    });
    return this.uncategorized;
  },

  slugFor: function(category) {
    if (!category) return "";
    var id = Em.get(category, 'id');
    var slug = Em.get(category, 'slug');
    if (!slug || slug.trim().length === 0) return "" + id + "-category";
    return slug;
  },

  list: function() {
    return Discourse.Site.instance().get('categories');
  },

  findBySlugOrId: function(slugOrId) {
    // TODO: all our routing around categories need a rethink
    return Discourse.ajax("/category/" + slugOrId + "/show.json").then(function (result) {
      return Discourse.Category.create(result.category);
    });
  }
});
