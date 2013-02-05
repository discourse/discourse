Discourse.DropdownButtonView = Ember.View.extend Discourse.Presence,
  classNames: ['btn-group']
  attributeBindings: ['data-not-implemented']

  didInsertElement: (e) ->
    @.$('ul li').on 'click', (e) =>
      e.preventDefault()
      @clicked $(e.currentTarget).data('id')
      false

  clicked: (id) -> null

  textChanged: (->
    @rerender()
  ).observes('text','longDescription')

  render: (buffer) ->

    buffer.push("<h4 class='title'>#{@get('title')}</h4>")
    buffer.push("<button class='btn standard dropdown-toggle' data-toggle='dropdown'>")
    buffer.push(@get('text'))
    buffer.push("</button>")

    buffer.push("<ul class='dropdown-menu'>")
    @get('dropDownContent').each (row) ->
      id = row[0]
      textKey = row[1]
      title = Em.String.i18n("#{textKey}.title")
      description = Em.String.i18n("#{textKey}.description")

      buffer.push("<li data-id=\"#{id}\"><a href='#'>")
      buffer.push("<span class='title'>#{title}</span>")
      buffer.push("<span>#{description}</span>")
      buffer.push("</a></li>")
    buffer.push("</ul>")

    if desc = @get('longDescription')
      buffer.push("<p>")
      buffer.push(desc)
      buffer.push("</p>")

