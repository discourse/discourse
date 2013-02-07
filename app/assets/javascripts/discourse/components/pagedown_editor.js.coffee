window.Discourse.PagedownEditor = Ember.ContainerView.extend
  elementId: 'pagedown-editor'

  init: ->

    @_super()

    # Add a button bar
    @pushObject Em.View.create(elementId: 'wmd-button-bar')
    @pushObject Em.TextArea.create(valueBinding: 'parentView.value', elementId: 'wmd-input')
    @pushObject Em.View.createWithMixins Discourse.Presence,
      elementId: 'wmd-preview',
      classNameBindings: [':preview', 'hidden']

      hidden: (->
        @blank('parentView.value')
      ).property('parentView.value')


  didInsertElement: ->
    $wmdInput = $('#wmd-input')
    $wmdInput.data('init', true)
    @editor = new Markdown.Editor(Discourse.Utilities.markdownConverter(sanitize: true))
    @editor.run()
