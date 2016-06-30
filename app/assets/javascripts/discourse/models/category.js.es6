import { ajax } from 'discourse/lib/ajax';
import RestModel from 'discourse/models/rest';
import { on } from 'ember-addons/ember-computed-decorators';
import PermissionType from 'discourse/models/permission-type';

const Category = RestModel.extend({

  @on('init')
  setupGroupsAndPermissions() {
    const availableGroups = this.get('available_groups');
    if (!availableGroups) { return; }
    this.set("availableGroups", availableGroups);

    const groupPermissions = this.get('group_permissions');
    if (groupPermissions) {
      this.set('permissions', groupPermissions.map((elem) => {
        availableGroups.removeObject(elem.group_name);
        return {
          group_name: elem.group_name,
          permission: PermissionType.create({id: elem.permission_type})
        };
      }));
    }
  },

  availablePermissions: function(){
    return [  PermissionType.create({id: PermissionType.FULL}),
              PermissionType.create({id: PermissionType.CREATE_POST}),
              PermissionType.create({id: PermissionType.READONLY})
           ];
  }.property(),

  searchContext: function() {
    return ({ type: 'category', id: this.get('id'), category: this });
  }.property('id'),

  url: function() {
    return Discourse.getURL("/c/") + Category.slugFor(this);
  }.property('name'),

  fullSlug: function() {
    return this.get("url").slice(3).replace("/", "-");
  }.property("url"),

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

    return ajax(url, {
      data: {
        name: this.get('name'),
        slug: this.get('slug'),
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
        allow_badges: this.get('allow_badges'),
        custom_fields: this.get('custom_fields'),
        topic_template: this.get('topic_template'),
        suppress_from_homepage: this.get('suppress_from_homepage'),
        allowed_tags: this.get('allowed_tags'),
        allowed_tag_groups: this.get('allowed_tag_groups')
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
    return ajax("/categories/" + (this.get('id') || this.get('slug')), { type: 'DELETE' });
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
      {group_name: "everyone", permission: PermissionType.create({id: 1})},
      {group_name: "admins", permission: PermissionType.create({id: 2}) },
      {group_name: "crap", permission: PermissionType.create({id: 3}) }
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

  unreadTopics: function() {
    return this.topicTrackingState.countUnread(this.get('id'));
  }.property('topicTrackingState.messageCount'),

  newTopics: function() {
    return this.topicTrackingState.countNew(this.get('id'));
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
    return ajax(url, {
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

Category.reopenClass({

  findUncategorized() {
    _uncategorized = _uncategorized || Category.list().findBy('id', Discourse.Site.currentProp('uncategorized_category_id'));
    return _uncategorized;
  },

  slugFor(category, separator = "/") {
    if (!category) return "";

    const parentCategory = Em.get(category, 'parentCategory');
    let result = "";

    if (parentCategory) {
      result = Category.slugFor(parentCategory) + separator;
    }

    const id = Em.get(category, 'id'),
          slug = Em.get(category, 'slug');

    return !slug || slug.trim().length === 0 ? `${result}${id}-category` : result + slug;
  },

  list() {
    return Discourse.SiteSettings.fixed_category_positions ?
             Discourse.Site.currentProp('categories') :
             Discourse.Site.currentProp('sortedCategories');
  },

  listByActivity() {
    return Discourse.Site.currentProp('sortedCategories');
  },

  idMap() {
    return Discourse.Site.currentProp('categoriesById');
  },

  findSingleBySlug(slug) {
    return Category.list().find(c => Category.slugFor(c) === slug);
  },

  findById(id) {
    if (!id) { return; }
    return Category.idMap()[id];
  },

  findByIds(ids) {
    const categories = [];
    _.each(ids, id => {
      const found = Category.findById(id);
      if (found) {
        categories.push(found);
      }
    });
    return categories;
  },

  findBySlug(slug, parentSlug) {
    const categories = Category.list();
    let category;

    if (parentSlug) {
      const parentCategory = Category.findSingleBySlug(parentSlug);
      if (parentCategory) {
        if (slug === 'none') { return parentCategory; }

        category = categories.find(item => {
          return item && item.get('parentCategory') === parentCategory && Category.slugFor(item) === (parentSlug + "/" + slug);
        });
      }
    } else {
      category = Category.findSingleBySlug(slug);

      // If we have a parent category, we need to enforce it
      if (category && category.get('parentCategory')) return;
    }

    // In case the slug didn't work, try to find it by id instead.
    if (!category) {
      category = categories.findBy('id', parseInt(slug, 10));
    }

    return category;
  },

  reloadById(id) {
    return ajax(`/c/${id}/show.json`);
  },

  reloadBySlug(slug, parentSlug) {
    return parentSlug ? ajax(`/c/${parentSlug}/${slug}/find_by_slug.json`) : ajax(`/c/${slug}/find_by_slug.json`);
  },

  search(term, opts) {
    var limit = 5;

    if (opts) {
      if (opts.limit === 0) {
        return [];
      } else if (opts.limit) {
        limit = opts.limit;
      }
    }

    const emptyTerm = (term === "");
    let slugTerm = term;

    if (!emptyTerm) {
      term = term.toLowerCase();
      slugTerm = term;
      term = term.replace(/-/g, " ");
    }

    const categories = Category.listByActivity();
    const length = categories.length;
    var i;
    var data = [];

    const done = () => {
      return data.length === limit;
    };

    for (i = 0; i < length && !done(); i++) {
      const category = categories[i];
      if ((emptyTerm && !category.get('parent_category_id')) ||
          (!emptyTerm &&
           (category.get('name').toLowerCase().indexOf(term) === 0 ||
            category.get('slug').toLowerCase().indexOf(slugTerm) === 0))) {

        data.push(category);
      }
    }

    if (!done()) {
      for (i = 0; i < length && !done(); i++) {
        const category = categories[i];

        if (!emptyTerm &&
            (category.get('name').toLowerCase().indexOf(term) > 0 ||
             category.get('slug').toLowerCase().indexOf(slugTerm) > 0)) {

          if (data.indexOf(category) === -1) data.push(category);
        }
      }
    }

    return _.sortBy(data, (category) => {
      return category.get('read_restricted');
    });
  }
});

export default Category;
