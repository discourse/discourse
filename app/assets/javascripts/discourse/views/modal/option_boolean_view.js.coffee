window.Discourse.OptionBooleanView = Em.View.extend
  classNames: ['archetype-option'] 
  composerControllerBinding: 'Discourse.router.composerController'
  templateName: "modal/option_boolean"

  checkedChanged: (->   
    metaData = @get('parentView.metaData')    
    metaData.set(@get('content.key'), if @get('checked') then 'true' else 'false')
    @get('controller.controllers.composer').saveDraft()
  ).observes('checked')

  init: ->
    @._super()
    @set('context', @get('content'))