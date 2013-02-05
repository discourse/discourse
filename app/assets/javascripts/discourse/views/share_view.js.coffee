window.Discourse.ShareView = Discourse.View.extend
  templateName: 'share'
  elementId: 'share-link'
  classNameBindings: ['hasLink']

  title: (->
    if @get('controller.type') == 'topic'
      Em.String.i18n('share.topic')
    else
      Em.String.i18n('share.post')
  ).property('controller.type')

  hasLink: (->
    return 'visible' if @present('controller.link')
    null
  ).property('controller.link')

  linkChanged: (->
    if @present('controller.link')
      $('#share-link input').val(@get('controller.link')).select().focus()
  ).observes('controller.link')

  didInsertElement: ->

    $('html').on 'click.outside-share-link', (e) => 
      return if @.$().has(e.target).length isnt 0
      @get('controller').close()
      return true
    $('html').on 'touchstart.outside-share-link', (e) => 
      return if @.$().has(e.target).length isnt 0
      @get('controller').close()
      return true

    $('html').on 'click.discoure-share-link', '[data-share-url]', (e) =>
      e.preventDefault()
      $currentTarget = $(e.currentTarget)
      url = $currentTarget.data('share-url')

      # Relative urls
      if url.indexOf("/") is 0
        url = window.location.protocol + "//" + window.location.host + url

      @get('controller').shareLink(e, url)
      false


  willDestroyElement: ->
    $('html').off 'click.discoure-share-link'
    $('html').off 'click.outside-share-link'
    $('html').off 'touchstart.outside-share-link'
