/**
  This is a text field that supports a dynamic placeholder based on search context.

  @class SearchTextField
  @extends Discourse.TextField
  @namespace Discourse
  @module Discourse
**/

import TextField from 'discourse/views/text-field';

export default TextField.extend({

  /**
    A dynamic placeholder for the search field based on our context

    @property placeholder
  **/
  placeholder: function() {

    if(this.get('searchContextEnabled')){
      return "";
    }

    return I18n.t('search.title');
  }.property('searchContextEnabled')
});
