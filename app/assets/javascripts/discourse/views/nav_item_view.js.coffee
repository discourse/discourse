window.Discourse.NavItemView = Ember.View.extend
  tagName: 'li'
  classNameBindings: ['isActive','content.hasIcon:has-icon']
  attributeBindings: ['title']
  title: (->
    name = @get('content.name')
    categoryName = @get('content.categoryName')
    if categoryName
      extra = {categoryName: categoryName}
      name = "category"
    Ember.String.i18n("filters.#{name}.help", extra)
  ).property("content.filter")

  isActive: (->
    return "active" if @get("content.name") == @get("controller.filterMode")
    ""
  ).property("content.name","controller.filterMode")

  hidden: (-> not @get('content.visible')).property('content.visible')

  name: (->
    name = @get('content.name')
    categoryName = @get('content.categoryName')
    extra = count: @get('content.count') || 0
    if categoryName
      name = 'category'
      extra.categoryName = categoryName.capitalize()
    I18n.t("js.filters.#{name}.title", extra)
  ).property('count')

  render: (buffer) ->
    content = @get('content')
    buffer.push("<a href='#{content.get('href')}'>")
    buffer.push("<span class='#{content.get('name')}'></span>") if content.get('hasIcon')
    buffer.push(@get('name'))
    buffer.push("</a>")
