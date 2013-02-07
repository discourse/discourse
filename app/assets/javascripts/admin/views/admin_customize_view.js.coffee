Discourse.AdminCustomizeView = window.Discourse.View.extend
  templateName: 'admin/templates/customize'
  classNames: ['customize']
  contentBinding: 'controller.content'

  init: ->
    @_super()
    @set('selected', 'stylesheet')

  headerActive: (->
    @get('selected') == 'header'
  ).property('selected')

  stylesheetActive: (->
    @get('selected') == 'stylesheet'
  ).property('selected')

  selectHeader: ->
    @set('selected', 'header')

  selectStylesheet: ->
    @set('selected', 'stylesheet')


  didInsertElement: ->
    Mousetrap.bindGlobal ['meta+s', 'ctrl+s'], =>
      @get('controller').save()
      return false

  willDestroyElement: ->
    Mousetrap.unbindGlobal('meta+s','ctrl+s')


