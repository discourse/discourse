/**
  This route is used when listing a particular category's topics

  @class ListCategoryRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.ListCategoryRoute = Discourse.FilteredListRoute.extend({

  setupController: function(controller, model) {
    var slug = Em.get(model, 'slug');
    var category = Discourse.get('site.categories').findProperty('slug', slug);

    if (!category) {
      category = Discourse.get('site.categories').findProperty('id', parseInt(slug, 10));
    }
    if (!category) {
      category = Discourse.Category.create({ name: slug, slug: slug });
    }

    var listTopicsController = this.controllerFor('listTopics');
    if (listTopicsController) {
      var listContent = listTopicsController.get('content');
      if (listContent) {
        listContent.set('loaded', false);
      }
    }


    var listController = this.controllerFor('list');
    var urlId = Discourse.Utilities.categoryUrlId(category);
    listController.set('filterMode', "category/" + urlId);

    var router = this;
    listController.load("category/" + urlId).then(function(topicList) {
      listController.set('canCreateTopic', topicList.get('can_create_topic'));
      listController.set('category', category);
      router.controllerFor('listTopics').set('content', topicList);
    });
  }

});


