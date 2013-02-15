window.Discourse.UserActionGroup = Discourse.Model.extend
  push: (item)->
    @items = [] unless @items
    @items.push(item)
