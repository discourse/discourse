/**
  This view renders a participant in a topic

  @class ParticipantView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.ParticipantView = Discourse.View.extend({
  templateName: 'participant',

  toggled: function() {
    return this.get('controller.postStream.userFilters').contains(this.get('participant.username'));
  }.property('controller.postStream.userFilters.[]')

});


Discourse.View.registerHelper('participant', Discourse.ParticipantView);