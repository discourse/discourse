/**
  Markdown.js doesn't seem to do bold and italics at the same time if you surround code with
  three asterisks. This adds that support.

  @event register
  @namespace Discourse.Dialect
**/
Discourse.Dialect.on("register", function(event) {

  var dialect = event.dialect,
      MD = event.MD;


  var inlineBuilder = function(symbol, tag, surround) {
    return function(text, match, prev) {
      if (prev && (prev.length > 0)) {
        var last = prev[prev.length - 1];
        if (typeof last === "string" && (!last.match(/\W$/))) { return; }
      }

      var regExp = new RegExp("^\\" + symbol + "([^\\" + symbol + "]+)" + "\\" + symbol, "igm"),
          m = regExp.exec(text);

      if (m) {

        var contents = [tag].concat(this.processInline(m[1]));
        if (surround) {
          contents = [surround, contents];
        }

        return [m[0].length, contents];
      }
    };
  };

  dialect.inline['***'] = inlineBuilder('**', 'em', 'strong');
  dialect.inline['**'] = inlineBuilder('**', 'strong');
  dialect.inline['*'] = inlineBuilder('*', 'em');
  dialect.inline['_'] = inlineBuilder('_', 'em');



});
