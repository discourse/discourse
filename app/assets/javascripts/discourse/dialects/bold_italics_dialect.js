/**
  Markdown.js doesn't seem to do bold and italics at the same time if you surround code with
  three asterisks. This adds that support.

  @event register
  @namespace Discourse.Dialect
**/
Discourse.Dialect.on("register", function(event) {

  var dialect = event.dialect,
      MD = event.MD;

  /**
    Handles simultaneous bold and italics

    @method parseMentions
    @param {String} text the text match
    @param {Array} match the match found
    @param {Array} prev the previous jsonML
    @return {Array} an array containing how many chars we've replaced and the jsonML content for it.
    @namespace Discourse.Dialect
  **/
  dialect.inline['***'] = function boldItalics(text, match, prev) {
    var regExp = /^\*{3}([^\*]+)\*{3}/,
        m = regExp.exec(text);

    if (m) {
      return [m[0].length, ['strong', ['em'].concat(this.processInline(m[1]))]];
    }
  };

});
