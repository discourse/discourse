window.Discourse.Model = Ember.Object.extend

  # Our own AJAX handler that handles erronous responses
  ajax: (url, args) ->

    # Error handler
    oldError = args.error
    args.error = (xhr) =>
      oldError($.parseJSON(xhr.responseText).errors)

    $.ajax(url, args)

  # Update our object from another object
  mergeAttributes: (attrs, builders) ->
    Object.keys attrs, (k, v) =>

      # If they're in a builder we use that
      if typeof(v) == 'object' and builders and builder = builders[k]
        @set(k, Em.A()) unless @get(k)
        col = @get(k)
        v.each (obj) -> col.pushObject(builder.create(obj))
      else
        @set(k, v)


window.Discourse.Model.reopenClass

  # Given an array of values, return them in a hash
  extractByKey: (collection, klass) ->
    retval = {}
    return retval unless collection

    collection.each (c) ->
      obj = klass.create(c)
      retval[c.id] = obj
    retval
