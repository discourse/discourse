window.Discourse.AdminSiteSettingsController = Ember.ArrayController.extend Discourse.Presence,

  filter: null
  onlyOverridden: false

  filteredContent: (->
    return null unless @present('content')
    filter = @get('filter').toLowerCase() if @get('filter')

    @get('content').filter (item, index, enumerable) =>

      return false if @get('onlyOverridden') and !item.get('overridden')

      if filter
        return true if item.get('setting').toLowerCase().indexOf(filter) > -1
        return true if item.get('description').toLowerCase().indexOf(filter) > -1
        return true if item.get('value').toLowerCase().indexOf(filter) > -1
        return false
      else
        true
  ).property('filter', 'content.@each', 'onlyOverridden')

  
  resetDefault: (setting) ->
    setting.set('value', setting.get('default'))
    setting.save()

  save: (setting) -> setting.save()

  cancel: (setting) -> setting.resetValue()