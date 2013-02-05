Discourse.ButtonView = Ember.View.extend Discourse.Presence,
  tagName: 'button'
  classNameBindings: [':btn', ':standard', 'dropDownToggle']
  attributeBindings: ['data-not-implemented', 'title', 'data-toggle', 'data-share-url']

  title: (->
    Em.String.i18n(@get('helpKey') || @get('textKey'))
  ).property('helpKey')

  text: (->
    Em.String.i18n(@get('textKey'))
  ).property('textKey')

  render: (buffer) ->
    @renderIcon(buffer) if @renderIcon
    buffer.push(@get('text'))
