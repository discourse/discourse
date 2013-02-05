window.Discourse.CreateAccountView = window.Discourse.ModalBodyView.extend Discourse.Presence,
  templateName: 'modal/create_account'
  title: Em.String.i18n('create_account.title')  
  uniqueUsernameValidation: null
  complete: false


  submitDisabled: (->
    return true if @get('nameValidation.failed')
    return true if @get('emailValidation.failed')
    return true if @get('usernameValidation.failed')
    return true if @get('passwordValidation.failed')
    false
  ).property('nameValidation.failed', 'emailValidation.failed', 'usernameValidation.failed', 'passwordValidation.failed')

  passwordRequired: (->
    @blank('authOptions.auth_provider')
  ).property('authOptions.auth_provider')

  # Validate the name
  nameValidation: (->
    # If blank, fail without a reason
    return Discourse.InputValidation.create(failed: true) if @blank('accountName') 

    # If too short
    return Discourse.InputValidation.create(failed: true, reason: Em.String.i18n('user.name.too_short')) if @get('accountName').length < 3

    # Looks good!
    Discourse.InputValidation.create(ok: true, reason: Em.String.i18n('user.name.ok')) 
  ).property('accountName')


  # Check the email address
  emailValidation: (->
    # If blank, fail without a reason
    return Discourse.InputValidation.create(failed: true) if @blank('accountEmail') 

    email = @get("accountEmail")
    if (@get('authOptions.email') is email) and @get('authOptions.email_valid')
      return Discourse.InputValidation.create(ok: true, reason: Em.String.i18n('user.email.authenticated', provider: @get('authOptions.auth_provider'))) 

    if Discourse.Utilities.emailValid(email)
      return Discourse.InputValidation.create(ok: true, reason: Em.String.i18n('user.email.ok')) 

    return Discourse.InputValidation.create(failed: true, reason: Em.String.i18n('user.email.invalid'))
  ).property('accountEmail')

  usernameMatch: (->
    if @get('emailValidation.failed')
      if @shouldCheckUsernameMatch()
        @set('uniqueUsernameValidation', Discourse.InputValidation.create(failed: true, reason: Em.String.i18n('user.username.enter_email')))
      else
        @set('uniqueUsernameValidation', Discourse.InputValidation.create(failed: true))
    else if @shouldCheckUsernameMatch()
      @set('uniqueUsernameValidation', Discourse.InputValidation.create(failed: true, reason: Em.String.i18n('user.username.checking')))
      @checkUsernameAvailability()
  ).observes('accountEmail')

  basicUsernameValidation: (->  
    @set('uniqueUsernameValidation', null)  

    # If blank, fail without a reason
    return Discourse.InputValidation.create(failed: true) if @blank('accountUsername')     # 

    # If too short
    return Discourse.InputValidation.create(failed: true, reason: Em.String.i18n('user.username.too_short')) if @get('accountUsername').length < 3

    @checkUsernameAvailability()

    # Let's check it out asynchronously
    Discourse.InputValidation.create(failed: true, reason: Em.String.i18n('user.username.checking')) 

  ).property('accountUsername')

  shouldCheckUsernameMatch: ->
    !@blank('accountUsername') and @get('accountUsername').length > 2

  checkUsernameAvailability: Discourse.debounce(->
    if @shouldCheckUsernameMatch()
      Discourse.User.checkUsername(@get('accountUsername'), @get('accountEmail')).then (result) =>
        if result.available
          if result.global_match
            @set('uniqueUsernameValidation', Discourse.InputValidation.create(ok: true, reason: Em.String.i18n('user.username.global_match')))
          else
            @set('uniqueUsernameValidation', Discourse.InputValidation.create(ok: true, reason: Em.String.i18n('user.username.available')))
        else
          if result.suggestion
            if result.global_match != undefined and result.global_match == false
              @set('uniqueUsernameValidation', Discourse.InputValidation.create(failed: true, reason: Em.String.i18n('user.username.global_mismatch', result)))
            else
              @set('uniqueUsernameValidation', Discourse.InputValidation.create(failed: true, reason: Em.String.i18n('user.username.not_available', result)))
          else if result.errors
            @set('uniqueUsernameValidation', Discourse.InputValidation.create(failed: true, reason: result.errors.join(' ')))
          else
            @set('uniqueUsernameValidation', Discourse.InputValidation.create(failed: true, reason: Em.String.i18n('user.username.enter_email', result)))
  , 500)

  # Actually wait for the async name check before we're 100% sure we're good to go
  usernameValidation: (->
    basicValidation = @get('basicUsernameValidation')
    uniqueUsername = @get('uniqueUsernameValidation')
    return uniqueUsername if uniqueUsername
    basicValidation    
  ).property('uniqueUsernameValidation', 'basicUsernameValidation')

  # Validate the password
  passwordValidation: (->

    return Discourse.InputValidation.create(ok: true) unless @get('passwordRequired') 

    # If blank, fail without a reason
    password = @get("accountPassword")  
    return Discourse.InputValidation.create(failed: true) if @blank('accountPassword') 

    # If too short
    return Discourse.InputValidation.create(failed: true, reason: Em.String.i18n('user.password.too_short')) if password.length < 6

    # Looks good!
    Discourse.InputValidation.create(ok: true, reason: Em.String.i18n('user.password.ok')) 
  ).property('accountPassword')


  createAccount: ->
    name = @get('accountName')
    email = @get('accountEmail')
    password = @get('accountPassword')
    username = @get('accountUsername')

    Discourse.User.createAccount(name, email, password, username).then (result) =>
      
      if result.success
        @flash(result.message)
        @set('complete', true) 
      else
        @flash(result.message, 'error')

      if result.active
        window.location.reload()
    , => 
      @flash(Em.String.i18n('create_account.failed'), 'error')  