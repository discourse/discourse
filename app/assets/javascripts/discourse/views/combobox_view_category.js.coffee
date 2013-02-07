window.Discourse.ComboboxViewCategory = Discourse.ComboboxView.extend

  none: 'category.none'
  dataAttributes: ['color']

  template: (text, templateData) ->
    return text unless templateData.color
    "<span class='badge-category' style='background-color: ##{templateData.color}'>#{text}</span>"
