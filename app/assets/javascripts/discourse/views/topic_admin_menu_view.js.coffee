window.Discourse.TopicAdminMenuView = Em.View.extend

  willDestroyElement: ->
    $('html').off 'mouseup.discourse-topic-admin-menu'

  didInsertElement: ->    
    $('html').on 'mouseup.discourse-topic-admin-menu', (e) =>
      $target = $(e.target)
      if $target.is('button') or @.$().has($target).length is 0        
        @get('controller').hide()

