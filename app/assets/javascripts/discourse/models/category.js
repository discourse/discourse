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
    this.set("permissions", Em.A(_.map(this.group_permissions, function(elem){
      return {
                group_name: elem.group_name,
                permission: Discourse.PermissionType.create({id: elem.permission_type})
      };
    })));
  },

  availablePermissions: function(){
    return [  Discourse.PermissionType.create({id: Discourse.PermissionType.FULL}),
              Discourse.PermissionType.create({id: Discourse.PermissionType.CREATE_POST}),
              Discourse.PermissionType.create({id: Discourse.PermissionType.READONLY})
           ];
  }.property(),

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
        permissions: this.get('permissionsForUpdate'),
        auto_close_days: this.get('auto_close_days'),
        position: this.get('position')
      },
      type: this.get('id') ? 'PUT' : 'POST'
    });
  },

  permissionsForUpdate: function(){
    var rval = {};
    _.each(this.get("permissions"),function(p){
      rval[p.group_name] = p.permission.id;
    });
    return rval;
  }.property("permissions"),

  destroy: function(callback) {
    return Discourse.ajax("/categories/" + (this.get('slug') || this.get('id')), { type: 'DELETE' });
  },

  addPermission: function(permission){
    this.get("permissions").addObject(permission);
    this.get("availableGroups").removeObject(permission.group_name);
  },


  removePermission: function(permission){
    this.get("permissions").removeObject(permission);
    this.get("availableGroups").addObject(permission.group_name);
  },

  // note, this is used in a data attribute, data attributes get downcased
  //  to avoid confusion later on using this naming here.
  description_text: function(){
    return $("<div>" + this.get("description") + "</div>").text();
  }.property("description"),

  permissions: function(){
    return Em.A([
      {group_name: "everyone", permission: Discourse.PermissionType.create({id: 1})},
      {group_name: "admins", permission: Discourse.PermissionType.create({id: 2}) },
      {group_name: "crap", permission: Discourse.PermissionType.create({id: 3}) }
    ]);
  }.property(),

  latestTopic: function(){
    return this.get("topics")[0];
  }.property("topics"),

  unreadTopics: function(){
    return Discourse.TopicTrackingState.current().countUnread(this.get('name'));
  }.property('Discourse.TopicTrackingState.current.messageCount'),

  newTopics: function(){
    return Discourse.TopicTrackingState.current().countNew(this.get('name'));
  }.property('Discourse.TopicTrackingState.current.messageCount')

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
    return Discourse.Site.currentProp('categories');
  },

  findBySlugOrId: function(slugOrId) {
    // TODO: all our routing around categories need a rethink
    return Discourse.ajax("/category/" + slugOrId + "/show.json").then(function (result) {
      return Discourse.Category.create(result.category);
    });
  }
});
