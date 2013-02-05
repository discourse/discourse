window.Discourse.MoveSelectedView = window.Discourse.ModalBodyView.extend Discourse.Presence,
  templateName: 'modal/move_selected'
  title: Em.String.i18n('topic.move_selected.title')

  saving: false

  selectedCount: (->
    return 0 unless @get('selectedPosts')
    @get('selectedPosts').length
  ).property('selectedPosts')

  buttonDisabled: (->
    return true if @get('saving')
    @blank('topicName')
  ).property('saving', 'topicName')

  buttonTitle: (->
    return Em.String.i18n('saving') if @get('saving')
    return Em.String.i18n('topic.move_selected.title')
  ).property('saving')

  movePosts: ->
    @set('saving', true)

    postIds = @get('selectedPosts').map (p) -> p.get('id')
    
    Discourse.Topic.movePosts(@get('topic.id'), @get('topicName'), postIds).then (result) =>
      if result.success
        $('#discourse-modal').modal('hide')
        Em.run.next ->
          Discourse.routeTo(result.url)
      else
        @flash(Em.String.i18n('topic.move_selected.error'))
        @set('saving', false)
    , =>
      @flash(Em.String.i18n('topic.move_selected.error'))
      @set('saving', false)

    false