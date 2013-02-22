/**
  This route is used when listing a particular category's topics

  @class ListCategoryRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.ListCategoryRoute = Discourse.FilteredListRoute.extend({

  setupController: function(controller, model) {
    var category, listController, slug, urlId,
      _this = this;
    slug = Em.get(model, 'slug');
    category = Discourse.get('site.categories').findProperty('slug', slug);

    if (!category) {
      category = Discourse.get('site.categories').findProperty('id', parseInt(slug, 10));
    }

    if (!category) {
      category = Discourse.Category.create({ name: slug, slug: slug });
    }

    listController = this.controllerFor('list');
    urlId = Discourse.Utilities.categoryUrlId(category);
    listController.set('filterMode', "category/" + urlId);
    listController.load("category/" + urlId).then(function(topicList) {
      listController.set('canCreateTopic', topicList.get('can_create_topic'));
      listController.set('category', category);
      _this.controllerFor('listTopics').set('content', topicList);
    });
  }

});


