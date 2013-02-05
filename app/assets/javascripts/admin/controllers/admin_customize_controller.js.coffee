window.Discourse.AdminCustomizeController = Ember.Controller.extend
  newCustomization: ->
    item = Discourse.SiteCustomization.create(name: 'New Style')
    @get('content').pushObject(item)
    @set('content.selectedItem', item)

  selectStyle: (style)-> @set('content.selectedItem', style)

  save: -> @get('content.selectedItem').save()

  delete: ->
    bootbox.confirm Em.String.i18n("admin.customize.delete_confirm"), Em.String.i18n("no_value"), Em.String.i18n("yes_value"), (result) =>
      if result
        selected = @get('content.selectedItem')
        selected.delete()
        @set('content.selectedItem', null)
        @get('content').removeObject(selected)

