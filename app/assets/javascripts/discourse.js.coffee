window.Discourse = Ember.Application.createWithMixins
  rootElement: '#main'

  # Data we want to remember for a short period
  transient: Em.Object.create()

  hasFocus: true
  scrolling: false

  # The highest seen post number by topic
  highestSeenByTopic: {}

  logoSmall: (->
    logo = Discourse.SiteSettings.logo_small_url
    if logo && logo.length > 1
      "<img src='#{logo}' width='33' height='33'>"
    else
      "<i class='icon-home'></i>"
  ).property()

  titleChanged: (->
    title = ""
    title += "#{@get('title')} - " if @get('title')
    title += Discourse.SiteSettings.title
    $('title').text(title)
    
    title = ("(*) " + title) if !@get('hasFocus') && @get('notify')

    # chrome bug workaround see: http://stackoverflow.com/questions/2952384/changing-the-window-title-when-focussing-the-window-doesnt-work-in-chrome
    window.setTimeout (->
      document.title = "."
      document.title = title
      return), 200
    return
  ).observes('title', 'hasFocus', 'notify')

  currentUserChanged: (->

    bus = Discourse.MessageBus

    # We don't want to receive any previous user notidications
    bus.unsubscribe "/notification"

    bus.callbackInterval =  Discourse.SiteSettings.anon_polling_interval
    bus.enableLongPolling = false
    
    user = @get('currentUser')
    if user
      bus.callbackInterval = Discourse.SiteSettings.polling_interval
      bus.enableLongPolling = true
      
      if user.admin
        bus.subscribe "/flagged_counts", (data) ->
          user.set('site_flagged_posts_count', data.total)
      bus.subscribe "/notification", ((data) ->
        user.set('unread_notifications', data.unread_notifications)
        user.set('unread_private_messages', data.unread_private_messages)), user.notification_channel_position

  ).observes('currentUser')

  notifyTitle: ->
    @set('notify', true)

  # Browser aware replaceState
  replaceState: (path) ->
    if window.history && window.history.pushState && window.history.replaceState && !navigator.userAgent.match(/((iPod|iPhone|iPad).+\bOS\s+[1-4]|WebApps\/.+CFNetwork)/)
      history.replaceState({path: path}, null, path) unless window.location.pathname is path

  openComposer: (opts) ->
    # TODO, remove container link
    Discourse.__container__.lookup('controller:composer')?.open(opts)

  # Like router.route, but allow full urls rather than relative ones
  # HERE BE HACKS - uses the ember container for now until we can do this nicer.
  routeTo: (path) ->
    path = path.replace(/https?\:\/\/[^\/]+/, '')

    # If we're in the same topic, don't push the state
    topicRegexp = /\/t\/([^\/]+)\/(\d+)\/?(\d+)?/
    newMatches = topicRegexp.exec(path);
    if newTopicId = newMatches?[2]
      oldMatches = topicRegexp.exec(window.location.pathname);
      if (oldTopicId = oldMatches?[2]) && (oldTopicId is newTopicId)
        Discourse.replaceState(path)
        topicController = Discourse.__container__.lookup('controller:topic')
        opts = {trackVisit: false}
        opts.nearPost = newMatches[3] if newMatches[3]
        topicController.get('content').loadPosts(opts)
        return


    # Be wary of looking up the router. In this case, we have links in our
    # HTML, say form compiled markdown posts, that need to be routed.    
    router = Discourse.__container__.lookup('router:main')   
    router.router.updateURL(path)    
    router.handleURL(path)
    
    # Scroll to the top if we're not replacing state
    

  # The classes of buttons to show on a post
  postButtons: (->
    Discourse.SiteSettings.post_menu.split("|").map (i) -> "#{i.replace(/\+/, '').capitalize()}"
  ).property('Discourse.SiteSettings.post_menu')

  bindDOMEvents: ->

    $html = $('html')
    # Add the discourse touch event
    hasTouch = false
    hasTouch = true if $html.hasClass('touch')
    hasTouch = true if (Modernizr.prefixed("MaxTouchPoints", navigator) > 1)

    if hasTouch
      $html.addClass('discourse-touch')
      @touch = true
      @hasTouch = true
    else
      $html.addClass('discourse-no-touch')
      @touch = false

    $('#main').on 'click.discourse', '[data-not-implemented=true]', (e) =>
      e.preventDefault()
      alert Em.String.i18n('not_implemented')
      false

    $('#main').on 'click.discourse', 'a', (e) =>

      return if (e.isDefaultPrevented() || e.metaKey || e.ctrlKey)
      $currentTarget = $(e.currentTarget)

      href = $currentTarget.attr('href')
      return if href is undefined
      return if href is '#'
      return if $currentTarget.attr('target')
      return if $currentTarget.data('auto-route')
      return if href.indexOf("mailto:") is 0

      if href.match(/^http[s]?:\/\//i) && !href.match new RegExp("^http:\\/\\/" + window.location.hostname,"i")
        return

      e.preventDefault()
      @routeTo(href)

      false

    $(window).focus( =>
      @set('hasFocus',true)
      @set('notify',false)
    ).blur( =>
      @set('hasFocus',false)
    )

  logout: ->
    username = @get('currentUser.username')
    Discourse.KeyValueStore.abandonLocal()
    $.ajax "/session/#{username}",
      type: 'DELETE'
      success: (result) =>
        # To keep lots of our variables unbound, we can handle a redirect on logging out.
        window.location.reload()

  # fancy probes in ember
  insertProbes: ->

    return unless console?

    topLevel = (fn,name) ->
      window.probes.measure fn,
        name: name
        before: (data,owner, args) ->
          if owner
            window.probes.clear()
          
        after: (data, owner, args) ->
          if owner && data.time > 10
            f = (name,data) ->
              "#{name} - #{data.count} calls #{(data.time + 0.0).toFixed(2)}ms" if data && data.count

            if console && console.group
              console.group(f(name, data))
            else
              console.log("")
              console.log(f(name,data))

            ary = []
            for n,v of window.probes
              continue if n == name || v.time < 1
              ary.push(k: n, v: v)
            
            ary.sortBy((item) -> if item.v && item.v.time then -item.v.time else 0).each (item)->
              console.log output if output = f("#{item.k}", item.v)
            console?.groupEnd?()

            window.probes.clear()


    Ember.View.prototype.renderToBuffer = window.probes.measure Ember.View.prototype.renderToBuffer, "renderToBuffer"

    Discourse.routeTo = topLevel(Discourse.routeTo, "Discourse.routeTo")
    Ember.run.end = topLevel(Ember.run.end, "Ember.run.end")

    return

  authenticationComplete: (options)->
    # TODO, how to dispatch this to the view without the container?
    loginView = Discourse.__container__.lookup('controller:modal').get('currentView')
    loginView.authenticationComplete(options)

  buildRoutes: (builder) ->
    oldBuilder = Discourse.routeBuilder
    Discourse.routeBuilder = ->
      oldBuilder.call(@) if oldBuilder
      builder.call(@)

  start: ->
    @bindDOMEvents()
    Discourse.SiteSettings = PreloadStore.getStatic('siteSettings')
    Discourse.MessageBus.start()
    Discourse.KeyValueStore.init("discourse_", Discourse.MessageBus)
    Discourse.insertProbes()
    

    # subscribe to any site customizations that are loaded 
    $('link.custom-css').each ->
      split = @href.split("/")
      id = split[split.length-1].split(".css")[0]
      stylesheet = @
      Discourse.MessageBus.subscribe "/file-change/#{id}", (data)=>
        $(stylesheet).data('orig', stylesheet.href) unless $(stylesheet).data('orig')
        orig = $(stylesheet).data('orig')
        sp = orig.split(".css?")
        stylesheet.href =  sp[0] + ".css?" + data

    $('header.custom').each ->
      header = $(this)
      Discourse.MessageBus.subscribe "/header-change/#{$(@).data('key')}", (data)->
        header.html(data)

    # possibly move this to dev only
    Discourse.MessageBus.subscribe "/file-change", (data)->
      Ember.TEMPLATES["empty"] = Handlebars.compile("")
      data.each (me)->
        if me == "refresh"
          document.location.reload(true)
        else if me.name.substr(-10) == "handlebars"
          js = me.name.replace(".handlebars","").replace("app/assets/javascripts","/assets")
          $LAB.script(js + "?hash=" + me.hash).wait ->
            templateName = js.replace(".js","").replace("/assets/","")
            $.each Ember.View.views, ->
              if(@get('templateName')==templateName)
                @set('templateName','empty')
                @rerender()
                Em.run.next =>
                  @set('templateName', templateName)
                  @rerender()
        else
          $('link').each ->
            if @href.match(me.name) and me.hash
              $(@).data('orig', @href) unless $(@).data('orig')
              @href = $(@).data('orig') + "&hash=" + me.hash

window.Discourse.Router = Discourse.Router.reopen(location: 'discourse_location')

# since we have no jquery-rails these days, hook up csrf token
csrf_token = $('meta[name=csrf-token]').attr('content')

$.ajaxPrefilter (options,originalOptions,xhr) ->
  unless options.crossDomain
    xhr.setRequestHeader('X-CSRF-Token', csrf_token)
  return

