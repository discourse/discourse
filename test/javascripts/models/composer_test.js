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


test('wouldLoseChanges', function() {
  var composer = Discourse.Composer.create();
  ok(!composer.get('wouldLoseChanges'), "by default it's false");

  composer.setProperties({
    originalText: "hello",
    reply: "hello"
  });

  ok(!composer.get('wouldLoseChanges'), "it's false when the originalText is the same as the reply");
  composer.set('reply', 'hello world');
  ok(composer.get('wouldLoseChanges'), "it's true when the reply changes");
});



test('importQuote with no data', function() {
  this.stub(Discourse.Post, 'load');
  var composer = Discourse.Composer.create();
  composer.importQuote();
  blank(composer.get('reply'), 'importing with no topic adds nothing');
  ok(!Discourse.Post.load.calledOnce, "load is not called");

  composer = Discourse.Composer.create({topic: Discourse.Topic.create()});
  composer.importQuote();
  blank(composer.get('reply'), 'importing with no posts in a topic adds nothing');
  ok(!Discourse.Post.load.calledOnce, "load is not called");
});

asyncTest('importQuote with a post', function() {
  expect(1);

  this.stub(Discourse.Post, 'load').withArgs(123).returns(Em.Deferred.promise(function (p) {
    p.resolve(Discourse.Post.create({raw: "let's quote"}));
  }));

  var composer = Discourse.Composer.create({post: Discourse.Post.create({id: 123})});
  composer.importQuote().then(function () {
    start();
    ok(composer.get('reply').indexOf("let's quote") > -1, "it quoted the post");
  });
});

asyncTest('importQuote with no post', function() {
  expect(1);

  this.stub(Discourse.Post, 'load').withArgs(4).returns(Em.Deferred.promise(function (p) {
    p.resolve(Discourse.Post.create({raw: 'quote me'}));
  }));

  var composer = Discourse.Composer.create({topic: Discourse.Topic.create()});
  composer.set('topic.postStream.stream', [4, 5]);
  composer.importQuote().then(function () {
    start();
    ok(composer.get('reply').indexOf('quote me') > -1, "it contains the word quote me");
  });

});
