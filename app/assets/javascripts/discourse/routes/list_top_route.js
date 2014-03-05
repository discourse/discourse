Discourse.ListTopRoute = Discourse.Route.extend({

  model: function(params) {
    this.controllerFor('listCategories').set('content', null);
    this.controllerFor('listTopics').set('content', null);
    this.controllerFor('list').set('loading', true);

    var category = Discourse.Category.findBySlug(params.slug, params.parentSlug);
    if (category) { this.set('category', category); }

    return Discourse.TopList.find(this.period, category);
  },

  activate: function() {
    this._super();
    this.controllerFor('list').setProperties({ filterMode: 'top', category: null });
  },

  redirect: function() { Discourse.redirectIfLoginRequired(this); },

  setupController: function(controller, model) {
    var category = this.get('category'),
        categorySlug = Discourse.Category.slugFor(category),
        url = category === undefined ? 'top' : 'category/' + categorySlug + '/l/top';

    this.controllerFor('listTop').setProperties({ content: model, category: category });
    this.controllerFor('list').setProperties({ loading: false, filterMode: url });

    if (category !== undefined) {
      this.controllerFor('list').set('category', category);
    }

    Discourse.set('title', I18n.t('filters.top.title'));
  },

  renderTemplate: function() {
    this.render('listTop', { into: 'list', outlet: 'listView' });
  }

});

Discourse.ListTopCategoryRoute = Discourse.ListTopRoute.extend({});
