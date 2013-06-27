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

});


test('missingReplyCharacters', function() {
  var missingReplyCharacters = function(val, isPM, expected, message) {
    var composer = Discourse.Composer.create({ reply: val, creatingPrivateMessage: isPM });
    equal(composer.get('missingReplyCharacters'), expected, message);
  };

  missingReplyCharacters('hi', false, Discourse.SiteSettings.min_post_length - 2, 'too short public post');
  missingReplyCharacters('hi', true,  Discourse.SiteSettings.min_private_message_post_length - 2, 'too short private message');
});

test('missingTitleCharacters', function() {
  var missingTitleCharacters = function(val, isPM, expected, message) {
    var composer = Discourse.Composer.create({ title: val, creatingPrivateMessage: isPM });
    equal(composer.get('missingTitleCharacters'), expected, message);
  };

  missingTitleCharacters('hi', false, Discourse.SiteSettings.min_topic_title_length - 2, 'too short post title');
  missingTitleCharacters('z', true,  Discourse.SiteSettings.min_private_message_title_length - 1, 'too short pm title');
});