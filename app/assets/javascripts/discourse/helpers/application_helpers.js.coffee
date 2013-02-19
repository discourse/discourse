Handlebars.registerHelper 'breakUp', (property, options) ->
  prop = Ember.Handlebars.get(this, property, options)
  return "" unless prop

  tokens = prop.match(RegExp(".{1,14}",'g'))
  return prop if tokens.length == 1

  result = ""
  tokens.each (token, index) ->
    result += token

    if token.indexOf(' ') == -1 and (index < tokens.length - 1)
      result += "- "

  result

Handlebars.registerHelper 'shorten', (property, options) ->
  str = Ember.Handlebars.get(this, property, options)
  str.truncate(35)

Handlebars.registerHelper 'topicLink', (property, options) ->
  topic = Ember.Handlebars.get(this, property, options)

  title = topic.get('fancy_title') || topic.get('title')
  "<a href='#{topic.get('lastReadUrl')}' class='title excerptable'>#{title}</a>"

Handlebars.registerHelper 'categoryLink', (property, options) ->
  category = Ember.Handlebars.get(this, property, options)
  new Handlebars.SafeString(Discourse.Utilities.categoryLink(category))

Handlebars.registerHelper 'titledLinkTo', (name, object) ->
  options = [].slice.call(arguments, -1)[0]

  if options.hash.titleKey
    options.hash.title = Em.String.i18n(options.hash.titleKey)

  if arguments.length is 3
    Ember.Handlebars.helpers.linkTo.call(this, name, object, options)
  else
    Ember.Handlebars.helpers.linkTo.call(this, name, options)


Handlebars.registerHelper 'shortenUrl', (property, options) ->
  url = Ember.Handlebars.get(this, property, options)

  # Remove trailing slash if it's a top level URL
  url = url.replace(/\/$/, '') if url.match(/\//g).length == 3

  url = url.replace(/^https?:\/\//, '')
  url = url.replace(/^www\./, '')
  url.truncate(80)

Handlebars.registerHelper 'lower', (property, options) ->
  o = Ember.Handlebars.get(this, property, options)
  if o && typeof o == 'string'
    o.toLowerCase()
  else
    ""

Handlebars.registerHelper 'avatar', (user, options) ->

  user = Ember.Handlebars.get(this, user, options) if typeof user is 'string'
  username = Em.get(user, 'username')
  username ||= Em.get(user, options.hash.usernamePath)
  title = Em.get(user, 'title') || Em.get(user, 'description') unless options.hash.ignoreTitle

  new Handlebars.SafeString Discourse.Utilities.avatarImg(
    size: options.hash.imageSize
    extraClasses: Em.get(user, 'extras') || options.hash.extraClasses
    username: username
    title: title || username
    avatarTemplate: Ember.get(user, 'avatar_template') || options.hash.avatarTemplate
  )

Handlebars.registerHelper 'unboundDate', (property, options) ->
  dt = new Date(Ember.Handlebars.get(this, property, options))
  dt.format("{d} {Mon}, {yyyy} {hh}:{mm}")

Handlebars.registerHelper 'editDate', (property, options) ->
  dt = Date.create(Ember.Handlebars.get(this, property, options))
  yesterday = new Date() - (60 * 60 * 24 * 1000)
  if yesterday > dt.getTime()
    dt.format("{d} {Mon}, {yyyy} {hh}:{mm}")
  else
    humaneDate(dt)

Handlebars.registerHelper 'number', (property, options) ->
  orig = parseInt(Ember.Handlebars.get(this, property, options))

  orig = 0 if isNaN(orig)

  title = orig
  if options.hash.numberKey
    title = Em.String.i18n(options.hash.numberKey, number: orig)

  # Round off the thousands to one decimal place
  n = orig
  n = (orig / 1000).toFixed(1) + "K" if orig > 999
  new Handlebars.SafeString("<span class='number' title='#{title}'>#{n}</span>")

Handlebars.registerHelper 'date', (property, options) ->

  if property.hash
    leaveAgo = property.hash.leaveAgo == "true" if property.hash.leaveAgo
    property = property.hash.path if property.hash.path

  val = Ember.Handlebars.get(this, property, options)
  return new Handlebars.SafeString("&mdash;") unless val

  dt = new Date(val)

  fullReadable = dt.format("{d} {Mon}, {yyyy} {hh}:{mm}")
  displayDate = ""

  fiveDaysAgo = ((new Date()) - 432000000) # 5 * 1000 * 60 * 60 * 24  - optimised 5 days ago

  if fiveDaysAgo > (dt.getTime())
    if (new Date()).getFullYear() != dt.getFullYear()
      displayDate = dt.format("{d} {Mon} '{yy}")
    else
      displayDate = dt.format("{d} {Mon}")
  else
    humanized = humaneDate(dt)
    return "" unless humanized
    displayDate = humanized
    displayDate = displayDate.replace(' ago', '') unless leaveAgo

  new Handlebars.SafeString("<span class='date' title='#{fullReadable}'>#{displayDate}</span>")

Handlebars.registerHelper 'personalizedName', (property, options) ->
  name = Ember.Handlebars.get(this, property, options);
  username = Ember.Handlebars.get(this, options.hash.usernamePath, options) if options.hash.usernamePath
  
  return name unless username == Discourse.get('currentUser.username')
  return Em.String.i18n('you')
