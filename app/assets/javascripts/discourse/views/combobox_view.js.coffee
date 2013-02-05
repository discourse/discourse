Discourse.ComboboxView = window.Ember.View.extend
  tagName: 'select'
  classNames: ['combobox']
  valueAttribute: 'id'

  render: (buffer) ->
    if @get('none')
      buffer.push("<option value=\"\">#{Ember.String.i18n(@get('none'))}</option>")

    selected = @get('value')?.toString()
    if @get('content')
      @get('content').each (o) =>
        val = o[@get('valueAttribute')]?.toString()
        selectedText = if val == selected then "selected" else ""
        data = ""
        if @dataAttributes
          @dataAttributes.forEach (a) =>
            data += "data-#{a}=\"#{o.get(a)}\" "
        buffer.push("<option #{selectedText} value=\"#{val}\" #{data}>#{o.name}</option>")

  didInsertElement: ->
    $elem = @.$()
    $elem.chosen(template: @template, disable_search_threshold: 5)
    $elem.change (e) => @set('value', $(e.target).val())
