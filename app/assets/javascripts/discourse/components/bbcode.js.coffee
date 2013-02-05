Discourse.BBCode =

  QUOTE_REGEXP: /\[quote=([^\]]*)\]([\s\S]*?)\[\/quote\]/im

  # Define our replacers
  replacers:

    base:
      withoutArgs:
        "ol": (_, content) -> "<ol>#{content}</ol>"
        "li": (_, content) -> "<li>#{content}</li>"
        "ul": (_, content) -> "<ul>#{content}</ul>"
        "code": (_, content) -> "<pre>#{content}</pre>"
        "url": (_, url) -> "<a href=\"#{url}\">#{url}</a>"
        "email": (_, address) -> "<a href=\"mailto:#{address}\">#{address}</a>"
        "img": (_, src) -> "<img src=\"#{src}\">"
      withArgs:
        "url": (_, href, title) -> "<a href=\"#{href}\">#{title}</a>"
        "email": (_, address, title) -> "<a href=\"mailto:#{address}\">#{title}</a>"
        "color": (_, color, content) -> 
          return content unless /^(\#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?)|(aqua|black|blue|fuchsia|gray|green|lime|maroon|navy|olive|purple|red|silver|teal|white|yellow)$/.test(color)
          "<span style=\"color: #{color}\">#{content}</span>"

    # For HTML emails
    email:
      withoutArgs:
        "b": (_, content) -> "<b>#{content}</b>"
        "i": (_, content) -> "<i>#{content}</i>"
        "u": (_, content) -> "<u>#{content}</u>"
        "s": (_, content) -> "<s>#{content}</s>"
        "spoiler": (_, content) -> "<span style='background-color: #000'>#{content}</span>"        

      withArgs:
        "size": (_, size, content) -> "<span style=\"font-size: #{size}px\">#{content}</span>"      

    # For sane environments that support CSS
    default:
      withoutArgs:
        "b": (_, content) -> "<span class='bbcode-b'>#{content}</span>"
        "i": (_, content) -> "<span class='bbcode-i'>#{content}</span>"
        "u": (_, content) -> "<span class='bbcode-u'>#{content}</span>"
        "s": (_, content) -> "<span class='bbcode-s'>#{content}</span>"
        "spoiler": (_, content) -> "<span class=\"spoiler\">#{content}</span>"

      withArgs:
        "size": (_, size, content) -> "<span class=\"bbcode-size-#{size}\">#{content}</span>"

  # Apply a particular set of replacers
  apply: (text, environment) ->
    replacer = Discourse.BBCode.parsedReplacers()[environment]
    replacer.forEach (r) -> text = text.replace r.regexp, r.fn
    text

  parsedReplacers: ->
    return @parsed if @parsed
    result = {}

    Object.keys Discourse.BBCode.replacers, (name, rules) ->
      parsed = result[name] = []

      Object.keys Object.merge(Discourse.BBCode.replacers.base.withoutArgs, rules.withoutArgs), (tag, val) -> 
        parsed.push(regexp: RegExp("\\[#{tag}\\]([\\s\\S]*?)\\[\\/#{tag}\\]", "igm"), fn: val)

      Object.keys Object.merge(Discourse.BBCode.replacers.base.withArgs, rules.withArgs), (tag, val) -> 
        parsed.push(regexp: RegExp("\\[#{tag}=?(.+?)\\\]([\\s\\S]*?)\\[\\/#{tag}\\]", "igm"), fn: val)

    @parsed = result
    @parsed

  buildQuoteBBCode: (post, contents="") ->
    sansQuotes = contents.replace(@QUOTE_REGEXP, '').trim()
    return "" if sansQuotes.length == 0

    # Strip the HTML from cooked
    tmp = document.createElement('div')
    tmp.innerHTML = post.get('cooked')
    stripped = tmp.textContent||tmp.innerText

    # Let's remove any non alphanumeric characters as a kind of hash. Yes it's
    # not accurate but it should work almost every time we need it to. It would be unlikely
    # that the user would quote another post that matches in exactly this way.
    stripped_hashed = stripped.replace(/[^a-zA-Z0-9]/g, '')
    contents_hashed = contents.replace(/[^a-zA-Z0-9]/g, '')

    result = "[quote=\"#{post.get('username')}, post:#{post.get('post_number')}, topic:#{post.get('topic_id')}"

    # If the quote is the full message, attribute it as such
    if stripped_hashed == contents_hashed
      result += ", full:true"

    result += "\"]#{sansQuotes}[/quote]\n\n"

  formatQuote: (text, opts) ->

    # Replace quotes with appropriate markup
    while matches = @QUOTE_REGEXP.exec(text)
      paramsString = matches[1]
      paramsString = paramsString.replace(/\"/g, '')
      paramsSplit = paramsString.split(/\, */)

      params=[]
      paramsSplit.each (p, i) ->
        if i > 0
          assignment = p.split(':')
          if assignment[0] and assignment[1]
            params.push(key: assignment[0], value: assignment[1].trim())

      username = paramsSplit[0]

      # Arguments for formatting
      args =
        username: username
        params: params
        quote: matches[2].trim()
        avatarImg: opts.lookupAvatar(username) if opts.lookupAvatar

      templateName = 'quote'
      templateName = "quote_#{opts.environment}" if opts?.environment

      text = text.replace(matches[0], "</p>" + HANDLEBARS_TEMPLATES[templateName](args) + "<p>")

    text

  format: (text, opts) ->
    text = Discourse.BBCode.apply(text, opts?.environment || 'default')

    # Add quotes
    text = Discourse.BBCode.formatQuote(text, opts)

    text
