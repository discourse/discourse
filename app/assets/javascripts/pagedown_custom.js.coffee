window.PagedownCustom =

  insertButtons: [
    id: 'wmd-quote-post'
    description: 'Quote Post'
    execute: ->
      # AWFUL but I can't figure out how to call a controller method from outside
      # my app?
      Discourse.__container__.lookup('controller:composer').importQuote()
  ]
