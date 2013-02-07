( ($) ->

  template = null

  $.fn.autocomplete = (options)->

    return if @length == 0

    if options && options.cancel && @data("closeAutocomplete")
      @data("closeAutocomplete")()
      return this

    alert "only supporting one matcher at the moment" unless @length == 1

    autocompleteOptions = null
    selectedOption = null
    completeStart = null
    completeEnd = null
    me = @
    div = null

    # input is handled differently
    isInput = @[0].tagName == "INPUT"

    inputSelectedItems = []
    addInputSelectedItem = (item) ->

      transformed = options.transformComplete(item) if options.transformComplete
      d = $("<div class='item'><span>#{transformed || item}<a href='#'><i class='icon-remove'></i></a></span></div>")
      prev = me.parent().find('.item:last')
      if prev.length == 0
        me.parent().prepend(d)
      else
        prev.after(d)

      inputSelectedItems.push(item)

      if options.onChangeItems
        options.onChangeItems(inputSelectedItems)

      d.find('a').click ->
        closeAutocomplete()
        inputSelectedItems.splice($.inArray(item),1)
        $(this).parent().parent().remove()
        if options.onChangeItems
          options.onChangeItems(inputSelectedItems)

    if isInput

      width = @width()
      height = @height()

      wrap = @wrap("<div class='ac-wrap clearfix'/>").parent()

      wrap.width(width)

      @width(80)
      @attr('name', @attr('name') + "-renamed")

      vals = @val().split(",")

      vals.each (x)->
        unless x == ""
          x = options.reverseTransform(x) if options.reverseTransform
          addInputSelectedItem(x)

      @val("")
      completeStart = 0
      wrap.click =>
        @focus()
        true


    markSelected = ->
      links = div.find('li a')
      links.removeClass('selected')
      $(links[selectedOption]).addClass('selected')

    renderAutocomplete = ->
      div.hide().remove() if div
      return if autocompleteOptions.length == 0
      div = $(options.template(options: autocompleteOptions))

      ul = div.find('ul')
      selectedOption = 0
      markSelected()
      ul.find('li').click ->
        selectedOption = ul.find('li').index(this)
        completeTerm(autocompleteOptions[selectedOption])

      pos = null
      if isInput
        pos =
          left: 0
          top: 0
      else
        pos = me.caretPosition(pos: completeStart, key: options.key)

      div.css(left: "-1000px")
      me.parent().append(div)

      mePos = me.position()

      borderTop = parseInt(me.css('border-top-width')) || 0
      div.css
        position: 'absolute',
        top: (mePos.top + pos.top - div.height() + borderTop) + 'px',
        left: (mePos.left + pos.left + 27) + 'px'


    updateAutoComplete = (r)->
      return if completeStart == null
      autocompleteOptions = r
      if !r || r.length == 0
        closeAutocomplete()
      else
        renderAutocomplete()

    closeAutocomplete = ->
      div.hide().remove() if div
      div = null
      completeStart = null
      autocompleteOptions = null

    # chain to allow multiples
    oldClose = me.data("closeAutocomplete")
    me.data "closeAutocomplete", ->
      oldClose() if oldClose
      closeAutocomplete()

    completeTerm = (term) ->
      if term
        if isInput
          me.val("")
          addInputSelectedItem(term)
        else
          term = options.transformComplete(term) if options.transformComplete
          text = me.val()
          text = text.substring(0, completeStart) + (options.key || "") + term + ' ' + text.substring(completeEnd+1, text.length)
          me.val(text)
          Discourse.Utilities.setCaretPosition(me[0], completeStart + 1 + term.length)
      closeAutocomplete()

    $(@).keypress (e) ->


      if !options.key
        return

      # keep hunting backwards till you hit a

      if e.which == options.key.charCodeAt(0)
        caretPosition = Discourse.Utilities.caretPosition(me[0])
        prevChar = me.val().charAt(caretPosition-1)
        if !prevChar || /\s/.test(prevChar)
          completeStart = completeEnd = caretPosition
          term = ""
          options.dataSource term, updateAutoComplete
      return

    $(@).keydown (e) ->

      completeStart = 0 if !options.key

      return if e.which == 16

      if completeStart == null && e.which == 8 && options.key #backspace

        c = Discourse.Utilities.caretPosition(me[0])
        next = me[0].value[c]
        nextIsGood = next == undefined || /\s/.test(next)

        c-=1
        initial = c

        prevIsGood = true
        while prevIsGood && c >= 0
          c -=1
          prev = me[0].value[c]
          stopFound = prev == options.key
          if stopFound
            prev = me[0].value[c-1]
            if !prev || /\s/.test(prev)
              completeStart = c
              caretPosition = completeEnd = initial
              term = me[0].value.substring(c+1, initial)
              options.dataSource term, updateAutoComplete
              return true

          prevIsGood = /[a-zA-Z\.]/.test(prev)


      if e.which == 27 # esc key
        if completeStart != null
          closeAutocomplete()
          return false
        return true


      if (completeStart != null)

        caretPosition = Discourse.Utilities.caretPosition(me[0])
        # If we've backspaced past the beginning, cancel unless no key
        if caretPosition <= completeStart && options.key
          closeAutocomplete()
          return false

        # Keyboard codes! So 80's.
        switch e.which
          when 13, 39, 9 # enter, tab or right arrow completes
            return true unless autocompleteOptions
            if selectedOption >= 0 and userToComplete = autocompleteOptions[selectedOption]
              completeTerm(userToComplete)
            else
              # We're cancelling it, really.
              return true

            closeAutocomplete()
            return false
          when 38 # up arrow
            selectedOption = selectedOption - 1
            selectedOption = 0 if selectedOption < 0
            markSelected()
            return false
          when 40 # down arrow
            total = autocompleteOptions.length
            selectedOption = selectedOption + 1
            selectedOption = total - 1 if selectedOption >= total
            selectedOption = 0 if selectedOption < 0
            markSelected()
            return false
          else

            # otherwise they're typing - let's search for it!
            completeEnd = caretPosition
            caretPosition-- if (e.which == 8)

            if caretPosition < 0
              closeAutocomplete()
              if isInput
                i = wrap.find('a:last')
                i.click() if i

              return false

            term = me.val().substring(completeStart+(if options.key then 1 else 0), caretPosition)
            if (e.which > 48 && e.which < 90)
              term += String.fromCharCode(e.which)
            else
              term += "," unless e.which == 8 # backspace
            options.dataSource term, updateAutoComplete
            return true


)(jQuery)
