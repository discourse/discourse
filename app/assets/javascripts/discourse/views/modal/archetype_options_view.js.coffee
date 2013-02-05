window.Discourse.ArchetypeOptionsView = Em.ContainerView.extend
  metaDataBinding: 'parentView.metaData'

  init: ->
    @_super()
    metaData = @get('metaData')

    @get('archetype.options').forEach (a) =>
      switch a.option_type
        when 1
          checked = 
          @pushObject Discourse.OptionBooleanView.create
            content: a
            checked: (metaData.get(a.key) == 'true')

      
