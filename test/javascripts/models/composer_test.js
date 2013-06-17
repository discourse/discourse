/*global module:true test:true ok:true visit:true expect:true exists:true count:true equal:true */

module("Discourse.Composer");


test('replyLength', function() {

  var replyLength = function(val, expectedLength, text) {
    var composer = Discourse.Composer.create({ reply: val });
    equal(composer.get('replyLength'), expectedLength);
  };

  replyLength("basic reply", 11, "basic reply length");
  replyLength(" \nbasic reply\t", 11, "trims whitespaces");
  replyLength("ba sic\n\nreply", 12, "count only significant whitespaces");
  replyLength("1[quote=]not counted[/quote]2[quote=]at all[/quote]3", 3, "removes quotes");
  replyLength("1[quote=]not[quote=]counted[/quote]yay[/quote]2", 2, "handles nested quotes correctly");

})
