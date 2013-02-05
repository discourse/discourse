Discourse.ShareController = Ember.Controller.extend

  # When the user clicks the post number, we pop up a share box
  shareLink: (e, url) ->
    x = e.pageX - 150
    x = 25 if x < 25
    $('#share-link').css(left: "#{x}px", top: "#{e.pageY - 100}px")
    @set('link', url)
    false

  # Close the share controller 
  close: ->
    @set('link', '')
    false
