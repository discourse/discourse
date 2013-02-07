# caret position in textarea ... very hacky ... sorry
(($) ->

  # http://stackoverflow.com/questions/263743/how-to-get-caret-position-in-textarea
  getCaret = (el) ->
    if el.selectionStart
      return el.selectionStart
    else if document.selection
      el.focus()
      r = document.selection.createRange()
      return 0  if r is null
      re = el.createTextRange()
      rc = re.duplicate()
      re.moveToBookmark r.getBookmark()
      rc.setEndPoint "EndToStart", re
      return rc.text.length
    0

  clone = null
  $.fn.caretPosition = (options) ->

    clone.remove() if clone
    span = $("#pos span")
    textarea = $(this)
    getStyles = (el, prop) ->
      if el.currentStyle
        el.currentStyle
      else
        document.defaultView.getComputedStyle el, ""

    styles = getStyles(textarea[0])
    clone = $("<div><p></p></div>").appendTo("body")
    p = clone.find("p")
    clone.width textarea.width()
    clone.height textarea.height()

    important = (prop) ->
      styles.getPropertyValue(prop)

    clone.css
      border: "1px solid black"
      padding: important("padding")
      resize: important("resize")
      "max-height": textarea.height() + "px"
      "overflow-y": "auto"
      "word-wrap": "break-word"
      position: "absolute"
      left: "-7000px"

    p.css
      margin: 0
      padding: 0
      "word-wrap": "break-word"
      "letter-spacing": important("letter-spacing")
      "font-family": important("font-family")
      "font-size": important("font-size")
      "line-height": important("line-height")

    before = undefined
    after = undefined
    pos = if options && options.pos then options.pos else getCaret(textarea[0])
    val = textarea.val().replace("\r", "")
    if (options && options.key)
      val = val.substring(0,pos) + options.key + val.substring(pos)

    before = pos - 1
    after = pos
    insertSpaceAfterBefore = false

    # if before and after are \n insert a space
    insertSpaceAfterBefore = true  if val[before] is "\n" and val[after] is "\n"
    guard = (v) ->
      buf = v.replace(/</g,"&lt;")
      buf = buf.replace(/>/g,"&gt;")
      buf = buf.replace(/[ ]/g, "&#x200b;&nbsp;&#x200b;")
      buf.replace(/\n/g,"<br />")


    makeCursor = (pos, klass, color) ->
      l = val.substring(pos, pos + 1)
      return "<br>"  if l is "\n"
      "<span class='" + klass + "' style='background-color:" + color + "; margin:0; padding: 0'>" + guard(l) + "</span>"

    html = ""
    if before >= 0
      html += guard(val.substring(0, pos - 1)) + makeCursor(before, "before", "#d0ffff")
      html += makeCursor(0, "post-before", "#d0ffff")  if insertSpaceAfterBefore
    if after >= 0
      html += makeCursor(after, "after", "#ffd0ff")
      html += guard(val.substring(after + 1))  if after - 1 < val.length
    p.html html
    clone.scrollTop textarea.scrollTop()
    letter = p.find("span:first")
    pos = letter.offset()
    pos.left = pos.left + letter.width()  if letter.hasClass("before")
    pPos = p.offset()
    #clone.hide().remove()

    left: pos.left - pPos.left
    top: (pos.top - pPos.top) - clone.scrollTop()
) jQuery
