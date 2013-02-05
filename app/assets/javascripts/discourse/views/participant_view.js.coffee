window.Discourse.ParticipantView = Ember.View.extend
  templateName: 'participant'

  toggled: (->
    @get('controller.userFilters').contains(@get('participant.username'))
  ).property('controller.userFilters.[]')

