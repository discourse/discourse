/**
  A data model for archetypes such as polls, tasks, etc.

  @class Archetype
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.Archetype = Discourse.Model.extend({

  hasOptions: function() {
    if (!this.get('options')) return false;
    return this.get('options').length > 0;
  }.property('options.@each'),

  isDefault: function() {
    return this.get('id') === Discourse.Site.instance().get('default_archetype');
  }.property('id')

});


