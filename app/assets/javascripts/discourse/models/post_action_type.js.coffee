window.Discourse.PostActionType = Em.Object.extend

  alsoName: (->
    return Em.String.i18n('post.actions.flag') if @get('is_flag')
    @get('name')
  ).property('is_flag', 'name')

  alsoNameLower: (->
    @get('alsoName')?.toLowerCase()
  ).property('alsoName')

