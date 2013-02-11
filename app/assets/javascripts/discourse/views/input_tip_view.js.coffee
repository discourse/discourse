Discourse.InputTipView = Ember.View.extend Discourse.Presence,
  templateName: 'input_tip'
  classNameBindings: [':tip', 'good','bad']

  good: (->
    !@get('validation.failed')
  ).property('validation')

  bad: (->
    @get('validation.failed')
  ).property('validation')

  triggerRender: (->
    @rerender()
  ).observes('validation')

  render: (buffer) ->
    if reason = @get('validation.reason')
      icon = if @get('good') then 'icon-ok' else 'icon-remove'
      buffer.push "<i class=\"icon #{icon}\"></i> #{reason}"
