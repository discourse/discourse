(function() {

  window.Discourse.ParticipantView = Discourse.View.extend({
    templateName: 'participant',
    toggled: (function() {
      return this.get('controller.userFilters').contains(this.get('participant.username'));
    }).property('controller.userFilters.[]')
  });

}).call(this);
