window.Discourse.AdminFlagsController = Ember.Controller.extend

  clearFlags: (item) ->
    item.clearFlags().then (=>
      @content.removeObject(item)
      ), (->
        bootbox.alert("something went wrong")
      )

  adminOldFlagsView: (->
    @query == 'old'
  ).property('query')

  adminActiveFlagsView: (->
    @query == 'active'
  ).property('query')
