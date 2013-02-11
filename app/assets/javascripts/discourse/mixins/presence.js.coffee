window.Discourse.Presence = Em.Mixin.create

  # Is a property blank?
  blank: (name) ->
    prop = @get(name)
    return true unless prop

    switch typeof(prop)
      when "string"
        return prop.trim().isBlank()
      when "object"
        return Object.isEmpty(prop)
    false

  present: (name) -> not @blank(name)
