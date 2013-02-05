window.Discourse.LoginView = window.Discourse.ModalBodyView.extend Discourse.Presence,
  templateName: 'modal/login'
  siteBinding: 'Discourse.site'
  title: Em.String.i18n('login.title')
  authenticate: null
  loggingIn: false

  showView: (view) -> @get('controller').show(view)  

  newAccount: ->
    @showView(Discourse.CreateAccountView.create())

  forgotPassword: ->
    @showView(Discourse.ForgotPasswordView.create())

  loginButtonText: (->
    return Em.String.i18n('login.logging_in') if @get('loggingIn')
    return Em.String.i18n('login.title')
  ).property('loggingIn')

  loginDisabled: (->
    return true if @get('loggingIn')
    return true if @blank('loginName') or @blank('loginPassword')
    false
  ).property('loginName', 'loginPassword', 'loggingIn')

  login: ->
    @set('loggingIn', true)
    $.post("/session", login: @get('loginName'), password: @get('loginPassword'))
      .success (result) =>
        if result.error
          @set('loggingIn', false)
          @flash(result.error, 'error')
        else
          window.location.reload()
      .fail (result) =>
        @flash(Em.String.i18n('login.error'), 'error')
        @set('loggingIn', false)
    false

  authMessage: (->
    return "" if @blank('authenticate')
    Em.String.i18n("login.#{@get('authenticate')}.message")
  ).property('authenticate')

  twitterLogin: ()->
    @set('authenticate', 'twitter')
    left = @get('lastX') - 400
    top = @get('lastY') - 200
    window.open("/twitter/frame", "_blank", "menubar=no,status=no,height=400,width=800,left=" + left + ",top=" + top)
    
  facebookLogin: ()->
    @set('authenticate', 'facebook')
    left = @get('lastX') - 400
    top = @get('lastY') - 200
    window.open("/facebook/frame", "_blank", "menubar=no,status=no,height=400,width=800,left=" + left + ",top=" + top)

  openidLogin: (provider)->
    left = @get('lastX') - 400
    top = @get('lastY') - 200
    if(provider == "yahoo")
      @set("authenticate", 'yahoo')
      window.open("/user_open_ids/frame?provider=yahoo", "_blank", "menubar=no,status=no,height=400,width=800,left=" + left + ",top=" + top)
    else
      window.open("/user_open_ids/frame?provider=google", "_blank", "menubar=no,status=no,height=500,width=850,left=" + left + ",top=" + top)
      @set("authenticate", 'google')

  authenticationComplete: (options)->

    if options['awaiting_approval']
      @flash(Em.String.i18n('login.awaiting_approval'), 'success')
      @set('authenticate', null)
      return

    if options['awaiting_activation']
      @flash(Em.String.i18n('login.awaiting_confirmation'), 'success')
      @set('authenticate', null)
      return

    # Reload the page if we're authenticated
    if options['authenticated']
      window.location.reload()
      return

    @showView Discourse.CreateAccountView.create
      accountEmail: options['email']
      accountUsername: options['username']
      accountName: options['name']
      authOptions: options

  mouseMove: (e) ->
    @set('lastX', e.screenX)
    @set('lastY', e.screenY)

  didInsertElement: (e) ->
    Em.run.next =>
      $('#login-account-password').keydown (e) =>
        @login() if e.keyCode == 13

