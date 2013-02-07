window.Discourse.SiteCustomization = Discourse.Model.extend

  init: ->
    @_super()
    @startTrackingChanges()

  trackedProperties: ['enabled','name', 'stylesheet', 'header', 'override_default_style']

  description: (->
    "#{@name}#{if @enabled then ' (*)' else ''}"
  ).property('selected', 'name')

  changed: (->
    return false unless @originals
    @trackedProperties.any (p)=>
      @originals[p] != @get(p)
  ).property('override_default_style','enabled','name', 'stylesheet', 'header', 'originals') # TODO figure out how to call with apply

  startTrackingChanges: ->
    @set('originals',{})

    @trackedProperties.each (p)=>
      @originals[p] = @get(p)
      true

  previewUrl: (->
    "/?preview-style=#{@get('key')}"
  ).property('key')

  disableSave:(->
    !@get('changed')
  ).property('changed')

  save: ->
    @startTrackingChanges()
    data =
      name: @name
      enabled: @enabled
      stylesheet: @stylesheet
      header: @header
      override_default_style: @override_default_style

    $.ajax
      url: "/admin/site_customizations#{if @id then '/' + @id else ''}"
      data:
        site_customization: data
      type: if @id then 'PUT' else 'POST'

  delete: ->
    return unless @id
    $.ajax
      url: "/admin/site_customizations/#{ @id }"
      type: 'DELETE'

SiteCustomizations = Ember.ArrayProxy.extend
  selectedItemChanged: (->
    selected = @get('selectedItem')
    @get('content').each (i)->
      i.set('selected', selected == i)
  ).observes('selectedItem')


Discourse.SiteCustomization.reopenClass
  findAll: ->
    content = SiteCustomizations.create
      content: []
      loading: true

    $.ajax
      url: "/admin/site_customizations"
      dataType: "json"
      success: (data)=>
        data?.site_customizations.each (c)->
          item = Discourse.SiteCustomization.create(c)
          content.pushObject(item)
        content.set('loading',false)

    content
