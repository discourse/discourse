#
# We can insert data into the PreloadStore when the document is loaded.
# The data can be accessed once by a key, after which it is removed.
#
window.PreloadStore = 
  
  data: {}

  store: (key, value) ->
    @data[key] = value

  # To retrieve a key, you provide the key you want, plus a finder to 
  # load it if the key cannot be found. Once the key is used once, it is
  # removed from the store. So, for example, you can't load a preloaded topic
  # more than once.
  get: (key, finder) ->
    promise = new RSVP.Promise

    if @data[key]
      promise.resolve(@data[key])
      delete @data[key]
    else
      if finder
        result = finder()

        # If the finder returns a promise, we support that too
        if result.then
          result.then (result) -> 
            promise.resolve(result)
          , (result) -> promise.reject(result)
        else
          promise.resolve(result)
      else
        promise.resolve(undefined)

    promise

  # Does the store contain a particular key? Does not delete, just returns
  # true or false.
  contains: (key) -> @data[key] isnt undefined

  # If we are sure it's preloaded, we don't have to supply a finder. Just
  # returns undefined if it's not in the store. 
  getStatic: (key) -> 
    result = @data[key]
    delete @data[key]
    result
