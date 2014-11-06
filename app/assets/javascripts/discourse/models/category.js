Discourse.Category = Discourse.Model.extend({

  init: function() {
    this._super();
    var availableGroups = Em.A(this.get("available_groups"));

    this.set("availableGroups", availableGroups);
    this.set("permissions", Em.A(_.map(this.group_permissions, function(elem){
      availableGroups.removeObject(elem.group_name);
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
    return Discourse.getURL("/c/") + Discourse.Category.slugFor(this);
  }.property('name'),

  nameLower: function() {
    return this.get('name').toLowerCase();
  }.property('name'),

  unreadUrl: function() {
    return this.get('url') + '/l/unread';
  }.property('url'),

  newUrl: function() {
    return this.get('url') + '/l/new';
  }.property('url'),

  style: function() {
    return "background-color: #" + this.get('category.color') + "; color: #" + this.get('category.text_color') + ";";
  }.property('color', 'text_color'),

  moreTopics: function() {
    return this.get('topic_count') > Discourse.SiteSettings.category_featured_topics;
  }.property('topic_count'),

  save: function() {
    var url = "/categories";
    if (this.get('id')) {
      url = "/categories/" + this.get('id');
    }

    return Discourse.ajax(url, {
      data: {
        name: this.get('name'),
        color: this.get('color'),
        text_color: this.get('text_color'),
        secure: this.get('secure'),
        permissions: this.get('permissionsForUpdate'),
        auto_close_hours: this.get('auto_close_hours'),
        auto_close_based_on_last_post: this.get("auto_close_based_on_last_post"),
        position: this.get('position'),
        email_in: this.get('email_in'),
        email_in_allow_strangers: this.get('email_in_allow_strangers'),
        parent_category_id: this.get('parent_category_id'),
        logo_url: this.get('logo_url'),
        background_url: this.get('background_url'),
        allow_badges: this.get('allow_badges')
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

  destroy: function() {
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

  permissions: function(){
    return Em.A([
      {group_name: "everyone", permission: Discourse.PermissionType.create({id: 1})},
      {group_name: "admins", permission: Discourse.PermissionType.create({id: 2}) },
      {group_name: "crap", permission: Discourse.PermissionType.create({id: 3}) }
    ]);
  }.property(),

  latestTopic: function(){
    var topics = this.get('topics');
    if (topics && topics.length) {
      return topics[0];
    }
  }.property("topics"),

  featuredTopics: function() {
    var topics = this.get('topics');
    if (topics && topics.length) {
      return topics.slice(0, Discourse.SiteSettings.category_featured_topics || 2);
    }
  }.property('topics'),

  topicTrackingState: function(){
    return Discourse.TopicTrackingState.current();
  }.property(),

  unreadTopics: function(){
    return this.get('topicTrackingState').countUnread(this.get('id'));
  }.property('topicTrackingState.messageCount'),

  newTopics: function(){
    return this.get('topicTrackingState').countNew(this.get('id'));
  }.property('topicTrackingState.messageCount'),

  topicStatsTitle: function() {
    var string = I18n.t('categories.topic_stats');
    _.each(this.get('topicCountStats'), function(stat) {
      string += ' ' + I18n.t('categories.topic_stat_sentence', {count: stat.value, unit: stat.unit});
    }, this);
    return string;
  }.property('post_count'),

  postStatsTitle: function() {
    var string = I18n.t('categories.post_stats');
    _.each(this.get('postCountStats'), function(stat) {
      string += ' ' + I18n.t('categories.post_stat_sentence', {count: stat.value, unit: stat.unit});
    }, this);
    return string;
  }.property('post_count'),

  topicCountStats: function() {
    return this.countStats('topics');
  }.property('topics_year', 'topics_month', 'topics_week', 'topics_day'),

  setNotification: function(notification_level) {
    var url = "/category/" + this.get('id')+"/notifications";
    this.set('notification_level', notification_level);
    return Discourse.ajax(url, {
      data: {
        notification_level: notification_level
      },
      type: 'POST'
    });
  },

  postCountStats: function() {
    return this.countStats('posts');
  }.property('posts_year', 'posts_month', 'posts_week', 'posts_day'),

  countStats: function(prefix) {
    var stats = [], val;
    _.each(['day', 'week', 'month', 'year'], function(unit) {
      val = this.get(prefix + '_' + unit);
      if (val > 0) stats.pushObject({value: val, unit: I18n.t(unit)});
      if (stats.length === 2) return false;
    }, this);
    return stats;
  },

  isUncategorizedCategory: function() {
    return this.get('id') === Discourse.Site.currentProp("uncategorized_category_id");
  }.property('id')
});

var _uncategorized;

Discourse.Category.reopenClass({

  NotificationLevel: {
    WATCHING: 3,
    TRACKING: 2,
    REGULAR: 1,
    MUTED: 0
  },

  findUncategorized: function() {
    _uncategorized = _uncategorized || Discourse.Category.list().findBy('id', Discourse.Site.currentProp('uncategorized_category_id'));
    return _uncategorized;
  },

  slugFor: function(category) {
    if (!category) return "";

    var parentCategory = Em.get(category, 'parentCategory'),
        result = "";

    if (parentCategory) {
      result = Discourse.Category.slugFor(parentCategory) + "/";
    }

    var id = Em.get(category, 'id'),
        slug = Em.get(category, 'slug');

    if (!slug || slug.trim().length === 0) return result + id + "-category";
    return result + slug;
  },

  list: function() {
    return Discourse.Site.currentProp('sortedCategories');
  },

  idMap: function() {
    return Discourse.Site.currentProp('categoriesById');
  },

  findSingleBySlug: function(slug) {
    return Discourse.Category.list().find(function(c) {
      return Discourse.Category.slugFor(c) === slug;
    });
  },

  findById: function(id) {
    return Discourse.Category.idMap()[id];
  },

  findByIds: function(ids){
    var categories = [];
    _.each(ids, function(id){
      var found = Discourse.Category.findById(id);
      if(found){
        categories.push(found);
      }
    });
    return categories;
  },

  findBySlug: function(slug, parentSlug) {
    var categories = Discourse.Category.list(),
        category;

    if (parentSlug) {
      var parentCategory = Discourse.Category.findSingleBySlug(parentSlug);
      if (parentCategory) {
        if (slug === 'none') { return parentCategory; }

        category = categories.find(function(item) {
          return item && item.get('parentCategory') === parentCategory && Discourse.Category.slugFor(item) === (parentSlug + "/" + slug);
        });
      }
    } else {
      category = Discourse.Category.findSingleBySlug(slug);

      // If we have a parent category, we need to enforce it
      if (category && category.get('parentCategory')) return;
    }

    // In case the slug didn't work, try to find it by id instead.
    if (!category) {
      category = categories.findBy('id', parseInt(slug, 10));
    }

    return category;
  },

  reloadById: function(id) {
    return Discourse.ajax("/c/" + id + "/show.json").then(function (result) {
      return Discourse.Category.create(result.category);
    });
  }
});
