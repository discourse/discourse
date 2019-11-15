// TODO: This code should be moved to lib, it was heavily modified by us over the years, and mostly written by us
// except for the little snippet from StackOverflow
//
// http://stackoverflow.com/questions/263743/how-to-get-caret-position-in-textarea
var clone = null;

$.fn.caret = function(elem) {
  var getCaret = function(el) {
    var r, rc, re;
    if (el.selectionStart) {
      return el.selectionStart;
    } else if (document.selection) {
      el.focus();
      r = document.selection.createRange();
      if (!r) return 0;
      re = el.createTextRange();
      rc = re.duplicate();
      re.moveToBookmark(r.getBookmark());
      rc.setEndPoint("EndToStart", re);
      return rc.text.length;
    }
    return 0;
  };

  return getCaret(elem || this[0]);
};

/**
  This is a jQuery plugin to retrieve the caret position in a textarea

  @module $.fn.caretPosition
**/
$.fn.caretPosition = function(options) {
  var after,
    before,
    getStyles,
    guard,
    html,
    important,
    insertSpaceAfterBefore,
    letter,
    makeCursor,
    p,
    pPos,
    pos,
    span,
    styles,
    textarea,
    val;
  if (clone) {
    clone.remove();
  }
  span = $("#pos span");
  textarea = $(this);

  getStyles = function(el) {
    if (el.currentStyle) {
      return el.currentStyle;
    } else {
      return document.defaultView.getComputedStyle(el, "");
    }
  };

  important = function(prop) {
    return styles.getPropertyValue(prop);
  };

  styles = getStyles(textarea[0]);
  clone = $("<div><p></p></div>").appendTo("body");
  p = clone.find("p");

  var isRTL = $("html").hasClass("rtl");
  clone.css({
    border: "1px solid black",
    padding: important("padding"),
    resize: important("resize"),
    "max-height": textarea.height() + "px",
    "overflow-y": "auto",
    "word-wrap": "break-word",
    position: "absolute",
    left: isRTL ? "auto" : "-7000px",
    right: isRTL ? "-7000px" : "auto"
  });

  p.css({
    margin: 0,
    padding: 0,
    "word-wrap": "break-word",
    "letter-spacing": important("letter-spacing"),
    "font-family": important("font-family"),
    "font-size": important("font-size"),
    "line-height": important("line-height")
  });

  clone.width(textarea.width());
  clone.height(textarea.height());

  pos =
    options && (options.pos || options.pos === 0)
      ? options.pos
      : $.caret(textarea[0]);

  val = textarea.val().replace("\r", "");
  if (options && options.key) {
    val = val.substring(0, pos) + options.key + val.substring(pos);
  }
  before = pos - 1;
  after = pos;
  insertSpaceAfterBefore = false;

  // if before and after are \n insert a space
  if (val[before] === "\n" && val[after] === "\n") {
    insertSpaceAfterBefore = true;
  }

  guard = function(v) {
    var buf;
    buf = v.replace(/</g, "&lt;");
    buf = buf.replace(/>/g, "&gt;");
    buf = buf.replace(/[ ]/g, "&#x200b;&nbsp;&#x200b;");
    return buf.replace(/\n/g, "<br />");
  };

  makeCursor = function(pos, klass, color) {
    var l;
    l = val.substring(pos, pos + 1);
    if (l === "\n") return "<br>";
    return (
      "<span class='" +
      klass +
      "' style='background-color:" +
      color +
      "; margin:0; padding: 0'>" +
      guard(l) +
      "</span>"
    );
  };

  html = "";

  if (before >= 0) {
    html +=
      guard(val.substring(0, pos - 1)) +
      makeCursor(before, "before", "#d0ffff");
    if (insertSpaceAfterBefore) {
      html += makeCursor(0, "post-before", "#d0ffff");
    }
  }

  if (after >= 0) {
    html += makeCursor(after, "after", "#ffd0ff");
    if (after - 1 < val.length) {
      html += guard(val.substring(after + 1));
    }
  }

  p.html(html);
  clone.scrollTop(textarea.scrollTop());
  letter = p.find("span:first");
  pos = letter.offset();
  if (letter.hasClass("before")) {
    pos.left = pos.left + letter.width();
  }

  pPos = p.offset();
  var position = {
    left: pos.left - pPos.left,
    top: pos.top - pPos.top - clone.scrollTop()
  };

  clone.remove();
  return position;
};
