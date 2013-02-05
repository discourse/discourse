window.Discourse.Archetype = Discourse.Model.extend

  hasOptions: (->
    return false unless @get('options')
    @get('options').length > 0
  ).property('options.@each')

  isDefault: (->
    @get('id') == Discourse.get('site.default_archetype')
  ).property('id')

