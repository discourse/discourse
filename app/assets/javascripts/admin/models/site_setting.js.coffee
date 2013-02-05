window.Discourse.SiteSetting = Discourse.Model.extend Discourse.Presence,

  # Whether a property is short.
  short: (->
    return true if @blank('value')
    return @get('value').toString().length < 80
  ).property('value')

  # Whether the site setting has changed
  dirty: (->
    @get('originalValue') != @get('value')
  ).property('originalValue', 'value')

  overridden: (->
    val = @get('value')
    defaultVal = @get('default')
    return val.toString() != defaultVal.toString() if (val and defaultVal)
    return val != defaultVal
  ).property('value')

  resetValue: ->
    @set('value', @get('originalValue'))

  save: ->

    # Update the setting    
    $.ajax "/admin/site_settings/#{@get('setting')}",
      data:
        value: @get('value')
      type: 'PUT'
      success: => @set('originalValue', @get('value'))
    

window.Discourse.SiteSetting.reopenClass
  findAll: ->    
    result = Em.A()    
    $.get "/admin/site_settings", (settings) ->
      settings.each (s) -> 
        s.originalValue = s.value
        result.pushObject(Discourse.SiteSetting.create(s))
    result

