window.Discourse.ImageSelectorView = Ember.View.extend
  templateName: 'image_selector'
  classNames: ['image-selector']
  title: 'Insert Image'

  init: ->
    @._super()
    @set('localSelected', true)

  selectLocal: ->
    @set('localSelected', true)

  selectRemote: ->
    @set('localSelected', false)


  remoteSelected: (->
    !@get('localSelected')
  ).property('localSelected')


  upload: ->
    @get('uploadTarget').fileupload('send', fileInput: $('#filename-input'))
    $('#discourse-modal').modal('hide')

  add: ->
    @get('composer').addMarkdown("![image](#{$('#fileurl-input').val()})")
    $('#discourse-modal').modal('hide')



