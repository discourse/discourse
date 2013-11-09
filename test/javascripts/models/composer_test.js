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

test('replyDirty', function() {
  var composer = Discourse.Composer.create();
  ok(!composer.get('replyDirty'), "by default it's false");

  composer.setProperties({
    originalText: "hello",
    reply: "hello"
  });

  ok(!composer.get('replyDirty'), "it's false when the originalText is the same as the reply");
  composer.set('reply', 'hello world');
  ok(composer.get('replyDirty'), "it's true when the reply changes");
});

test("appendText", function() {
  var composer = Discourse.Composer.create();

  blank(composer.get('reply'), "the reply is blank by default");

  composer.appendText("hello");
  equal(composer.get('reply'), "hello", "it appends text to nothing");
  composer.appendText(" world");
  equal(composer.get('reply'), "hello world", "it appends text to existing text");

});

test("Title length for regular topics", function() {
  Discourse.SiteSettings.min_topic_title_length = 5;
  Discourse.SiteSettings.max_topic_title_length = 10;
  var composer = Discourse.Composer.create();

  composer.set('title', 'asdf');
  ok(!composer.get('titleLengthValid'), "short titles are not valid");

  composer.set('title', 'this is a long title');
  ok(!composer.get('titleLengthValid'), "long titles are not valid");

  composer.set('title', 'just right');
  ok(composer.get('titleLengthValid'), "in the range is okay");
});

test("Title length for private messages", function() {
  Discourse.SiteSettings.min_private_message_title_length = 5;
  Discourse.SiteSettings.max_topic_title_length = 10;
  var composer = Discourse.Composer.create({action: Discourse.Composer.PRIVATE_MESSAGE});

  composer.set('title', 'asdf');
  ok(!composer.get('titleLengthValid'), "short titles are not valid");

  composer.set('title', 'this is a long title');
  ok(!composer.get('titleLengthValid'), "long titles are not valid");

  composer.set('title', 'just right');
  ok(composer.get('titleLengthValid'), "in the range is okay");
});

test("Title length for private messages", function() {
  Discourse.SiteSettings.min_private_message_title_length = 5;
  Discourse.SiteSettings.max_topic_title_length = 10;
  var composer = Discourse.Composer.create({action: Discourse.Composer.PRIVATE_MESSAGE});

  composer.set('title', 'asdf');
  ok(!composer.get('titleLengthValid'), "short titles are not valid");

  composer.set('title', 'this is a long title');
  ok(!composer.get('titleLengthValid'), "long titles are not valid");

  composer.set('title', 'just right');
  ok(composer.get('titleLengthValid'), "in the range is okay");
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

test('editingFirstPost', function() {
  var composer = Discourse.Composer.create();
  ok(!composer.get('editingFirstPost'), "it's false by default");

  var post = Discourse.Post.create({id: 123, post_number: 2});
  composer.setProperties({post: post, action: Discourse.Composer.EDIT });
  ok(!composer.get('editingFirstPost'), "it's false when not editing the first post");

  post.set('post_number', 1);
  ok(composer.get('editingFirstPost'), "it's true when editing the first post");

});

asyncTestDiscourse('importQuote with a post', function() {
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

asyncTestDiscourse('importQuote with no post', function() {
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

test('clearState', function() {
  var composer = Discourse.Composer.create({
    originalText: 'asdf',
    reply: 'asdf2',
    post: Discourse.Post.create({id: 1}),
    title: 'wat'
  });

  composer.clearState();

  blank(composer.get('originalText'));
  blank(composer.get('reply'));
  blank(composer.get('post'));
  blank(composer.get('title'));

});

test('initial category when uncategorized is allowed', function() {
  Discourse.SiteSettings.allow_uncategorized_topics = true;
  var composer = Discourse.Composer.open({action: 'createTopic', draftKey: 'asfd', draftSequence: 1});
  equal(composer.get('categoryId'),undefined,"Uncategorized by default");
});

test('initial category when uncategorized is not allowed', function() {
  Discourse.SiteSettings.allow_uncategorized_topics = false;
  var composer = Discourse.Composer.open({action: 'createTopic', draftKey: 'asfd', draftSequence: 1});
  ok(composer.get('categoryId') === undefined, "Uncategorized by default. Must choose a category.");
});

test('showPreview', function() {
  var new_composer = function() {
    return Discourse.Composer.open({action: 'createTopic', draftKey: 'asfd', draftSequence: 1});
  };

  Discourse.Mobile.mobileView = true;
  equal(new_composer().get('showPreview'), false, "Don't show preview in mobile view");

  Discourse.KeyValueStore.set({ key: 'composer.showPreview', value: 'true' });
  equal(new_composer().get('showPreview'), false, "Don't show preview in mobile view even if KeyValueStore wants to");
  Discourse.KeyValueStore.remove('composer.showPreview');

  Discourse.Mobile.mobileView = false;
  equal(new_composer().get('showPreview'), true, "Show preview by default in desktop view");
});
