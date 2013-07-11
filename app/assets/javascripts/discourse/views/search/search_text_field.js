/**
  This is a text field that supports a dynamic placeholder based on search context.

  @class SearchTextField
  @extends Discourse.TextField
  @namespace Discourse
  @module Discourse
**/
Discourse.SearchTextField = Discourse.TextField.extend({

  /**
    A dynamic placeholder for the search field based on our context

    @property placeholder
  **/
  placeholder: function() {

    var ctx = this.get('searchContext');
    if (ctx) {
      switch(Em.get(ctx, 'type')) {
        case 'user':
          return I18n.t('search.prefer.user', {username: Em.get(ctx, 'user.username')});
        case 'category':
          return I18n.t('search.prefer.category', {category: Em.get(ctx, 'category.name')});
      }
    }

    return I18n.t('search.placeholder');
  }.property('searchContext')

});


