baseUrl = null
site = null

Discourse.Utilities =

  translateSize: (size)->
    switch size
      when 'tiny' then size=20
      when 'small' then size=25
      when 'medium' then size=32
      when 'large' then size=45
    return size

  categoryUrlId: (category) ->
    return "" unless category
    id = Em.get(category, 'id')
    slug = Em.get(category, 'slug')
    return "#{id}-category" if (!slug) or slug.isBlank()
    slug

  # Create a badge like category link
  categoryLink: (category) ->
    return "" unless category

    color = Em.get(category, 'color')
    name = Em.get(category, 'name')

    "<a href=\"/category/#{@categoryUrlId(category)}\" class=\"badge-category excerptable\" data-excerpt-size=\"medium\" style=\"background-color: ##{color}\">#{name}</a>"

  avatarUrl: (username, size, template)->
    return "" unless username
    size = Discourse.Utilities.translateSize(size)
    rawSize = (size * (window.devicePixelRatio || 1)).toFixed()

    return template.replace(/\{size\}/g, rawSize) if template

    "/users/#{username.toLowerCase()}/avatar/#{rawSize}?__ws=#{encodeURIComponent(Discourse.BaseUrl || "")}"

  avatarImg: (options)->
    size = Discourse.Utilities.translateSize(options.size)
    title = options.title || ""
    extraClasses = options.extraClasses || ""
    url = Discourse.Utilities.avatarUrl(options.username, options.size, options.avatarTemplate)
    "<img width='#{size}' height='#{size}' src='#{url}' class='avatar #{extraClasses || ""}' title='#{Handlebars.Utils.escapeExpression(title || "")}'>"

  postUrl: (slug, topicId, postNumber)->
    url = "/t/"
    url += slug + "/" if slug
    url += topicId
    url += "/#{postNumber}" if postNumber > 1
    url

  emailValid: (email)->
    # see:  http://stackoverflow.com/questions/46155/validate-email-address-in-javascript
    re = /^[a-zA-Z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-zA-Z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?$/
    re.test(email)

  selectedText: ->
    t = ''
    if window.getSelection
      t = window.getSelection().toString()
    else if document.getSelection
      t = document.getSelection().toString()
    else if document.selection
      t = document.selection.createRange().text
    String(t).trim()

  # Determine the position of the caret in an element
  caretPosition: (el) ->

    return el.selectionStart if el.selectionStart

    if document.selection
      el.focus()
      r = document.selection.createRange()
      return 0 if r == null

      re = el.createTextRange()
      rc = re.duplicate()
      re.moveToBookmark(r.getBookmark())
      rc.setEndPoint('EndToStart', re)
      return rc.text.length
    return 0

  # Set the caret's position
  setCaretPosition: (ctrl, pos) ->
    if(ctrl.setSelectionRange)
      ctrl.focus()
      ctrl.setSelectionRange(pos,pos)
      return

    if (ctrl.createTextRange)
      range = ctrl.createTextRange()
      range.collapse(true)
      range.moveEnd('character', pos)
      range.moveStart('character', pos)
      range.select()

  markdownConverter: (opts)->
    converter = new Markdown.Converter()

    mentionLookup = opts.mentionLookup if opts
    mentionLookup = mentionLookup || Discourse.Mention.lookupCache

    # Before cooking callbacks
    converter.hooks.chain "preConversion", (text) =>
      @trigger 'beforeCook', detail: text, opts: opts
      @textResult || text

    # Support autolinking of www.something.com
    converter.hooks.chain "preConversion", (text) ->
      text.replace /(^|[\s\n])(www\.[a-z\.\-\_\(\)\/\?\=\%0-9]+)/gim, (full, _, rest) ->
        " <a href=\"http://#{rest}\">#{rest}</a>"

    # newline prediction in trivial cases
    unless Discourse.SiteSettings.traditional_markdown_linebreaks
      converter.hooks.chain "preConversion", (text) ->
        result = text.replace /(^[\w\<][^\n]*\n+)/gim, (t) ->
          return t if t.match /\n{2}/gim
          t = t.replace "\n","  \n"

    # github style fenced code
    converter.hooks.chain "preConversion", (text) ->
      result = text.replace /^`{3}(?:(.*$)\n)?([\s\S]*?)^`{3}/gm, (wholeMatch,m1,m2) ->
        escaped = Handlebars.Utils.escapeExpression(m2)
        "<pre><code class='#{m1 || 'lang-auto'}'>#{escaped}</code></pre>"

    converter.hooks.chain "postConversion", (text) ->
      return "" unless text
      # don't to mention voodoo in pres
      text = text.replace /<pre>([\s\S]*@[\s\S]*)<\/pre>/gi, (wholeMatch, inner) ->
        "<pre>#{inner.replace(/@/g, '&#64;')}</pre>"

      # Add @mentions of names
      text = text.replace(/([\s\t>,:'|";\]])(@[A-Za-z0-9_-|\.]*[A-Za-z0-9_-|]+)(?=[\s\t<\!:|;',"\?\.])/g, (x,pre,name) ->
        if mentionLookup(name.substr(1))
          "#{pre}<a href='/users/#{name.substr(1).toLowerCase()}' class='mention'>#{name}</a>"
        else
          "#{pre}<span class='mention'>#{name}</span>")

      # a primitive attempt at oneboxing, this regex gives me much eye sores
      text = text.replace /(<li>)?((<p>|<br>)[\s\n\r]*)(<a href=["]([^"]+)[^>]*)>([^<]+<\/a>[\s\n\r]*(?=<\/p>|<br>))/gi, ->

        # We don't onebox items in a list
        return arguments[0] if arguments[1]

        url = arguments[5]
        onebox = Discourse.Onebox.lookupCache(url) if Discourse && Discourse.Onebox
        if onebox and !onebox.isBlank()
          return arguments[2] + onebox
        else
          return arguments[2] + arguments[4] + " class=\"onebox\" target=\"_blank\">" + arguments[6]

    converter.hooks.chain "postConversion", (text) =>
      Discourse.BBCode.format(text, opts)


    if opts.sanitize
      converter.hooks.chain "postConversion", (text) =>
        return "" unless window.sanitizeHtml
        sanitizeHtml(text)

    converter


  # Takes raw input and cooks it to display nicely (mostly markdown)
  cook: (raw, opts=null) ->

    opts ||= {}

    # Make sure we've got a string
    return "" unless raw
    return "" unless raw.length > 0

    @converter = @markdownConverter(opts)
    @converter.makeHtml(raw)


RSVP.EventTarget.mixin(Discourse.Utilities)
