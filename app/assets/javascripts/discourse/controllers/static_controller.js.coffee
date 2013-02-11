Discourse.StaticController = Ember.Controller.extend

  content: null

  loadPath: (path) ->
    @set('content', null)

    # Load from <noscript> if we have it.
    $preloaded = $("noscript[data-path=\"#{path}\"]")
    if $preloaded.length
      text = $preloaded.text()# + ""
      text = text.replace(/\<header[\s\S]*\<\/header\>/, '')
      @set('content', text)
    else
      jQuery.ajax
        url: "#{path}.json"
        success: (result) =>
          @set('content', result)


Discourse.StaticController.reopenClass(pages: ['faq', 'tos', 'privacy'])
