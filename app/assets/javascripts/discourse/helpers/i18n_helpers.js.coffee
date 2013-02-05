Ember.Handlebars.registerHelper 'i18n', (property, options) ->

  # Resolve any properties
  params = options.hash
  Object.keys params, (key, value) =>
    params[key] = Em.Handlebars.get(this, value, options)

  Ember.String.i18n(property, params)

# We always prefix with .js to select exactly what we want passed through to the front end.
Ember.String.i18n = (scope, options) ->
  I18n.translate("js.#{scope}", options)

# Bind an i18n count
Ember.Handlebars.registerHelper 'countI18n', (key, options) ->
  view = Em.View.extend
    tagName: 'span'
    render: (buffer) -> buffer.push(Ember.String.i18n(key, count: @get('count')))
    countChanged: (-> @rerender() ).observes('count')

  Ember.Handlebars.helpers.view.call(this, view, options)

if Ember.EXTEND_PROTOTYPES
  String.prototype.i18n = (options) ->
    return Ember.String.i18n(String(this), options)
