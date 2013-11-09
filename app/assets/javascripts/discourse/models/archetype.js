/**
  A data model for archetypes such as polls, tasks, etc.

  @class Archetype
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.Archetype = Discourse.Model.extend({

  hasOptions: Em.computed.gt('options.length', 0),

  site: function() {
    return Discourse.Site.current();
  }.property(),

  isDefault: Discourse.computed.propertyEqual('id', 'site.default_archetype'),
  notDefault: Em.computed.not('isDefault')

});


