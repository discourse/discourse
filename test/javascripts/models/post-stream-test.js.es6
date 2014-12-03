module("Discourse.PostStream");

var buildStream = function(id, stream) {
  var topic = Discourse.Topic.create({id: id});
  var ps = topic.get('postStream');
  if (stream) {
    ps.set('stream', stream);
  }
  return ps;
};

var participant = {username: 'eviltrout'};

test('create', function() {
  ok(Discourse.PostStream.create(), 'it can be created with no parameters');
});

test('defaults', function() {
  var postStream = buildStream(1234);
  blank(postStream.get('posts'), "there are no posts in a stream by default");
  ok(!postStream.get('loaded'), "it has never loaded");
  present(postStream.get('topic'));

});

test('appending posts', function() {
  var postStream = buildStream(4567, [1, 3, 4]);

  equal(postStream.get('lastPostId'), 4, "the last post id is 4");

  ok(!postStream.get('hasPosts'), "there are no posts by default");
  ok(!postStream.get('firstPostPresent'), "the first post is not loaded");
  ok(!postStream.get('loadedAllPosts'), "the last post is not loaded");
  equal(postStream.get('posts.length'), 0, "it has no posts initially");

  postStream.appendPost(Discourse.Post.create({id: 2, post_number: 2}));
  ok(!postStream.get('firstPostPresent'), "the first post is still not loaded");
  equal(postStream.get('posts.length'), 1, "it has one post in the stream");

  postStream.appendPost(Discourse.Post.create({id: 4, post_number: 4}));
  ok(!postStream.get('firstPostPresent'), "the first post is still loaded");
  ok(postStream.get('loadedAllPosts'), "the last post is now loaded");
  equal(postStream.get('posts.length'), 2, "it has two posts in the stream");

  postStream.appendPost(Discourse.Post.create({id: 4, post_number: 4}));
  equal(postStream.get('posts.length'), 2, "it will not add the same post with id twice");

  var stagedPost = Discourse.Post.create({raw: 'incomplete post'});
  postStream.appendPost(stagedPost);
  equal(postStream.get('posts.length'), 3, "it can handle posts without ids");
  postStream.appendPost(stagedPost);
  equal(postStream.get('posts.length'), 3, "it won't add the same post without an id twice");


  // change the stream
  postStream.set('stream', [1, 2, 4]);
  ok(!postStream.get('firstPostPresent'), "the first post no longer loaded since the stream changed.");
  ok(postStream.get('loadedAllPosts'), "the last post is still the last post in the new stream");
});

test('closestPostNumberFor', function() {
  var postStream = buildStream(1231);

  blank(postStream.closestPostNumberFor(1), "there is no closest post when nothing is loaded");

  postStream.appendPost(Discourse.Post.create({id: 1, post_number: 2}));
  postStream.appendPost(Discourse.Post.create({id: 2, post_number: 3}));

  equal(postStream.closestPostNumberFor(2), 2, "If a post is in the stream it returns its post number");
  equal(postStream.closestPostNumberFor(3), 3, "If a post is in the stream it returns its post number");
  equal(postStream.closestPostNumberFor(10), 3, "it clips to the upper bound of the stream");
  equal(postStream.closestPostNumberFor(0), 2, "it clips to the lower bound of the stream");
});

test('updateFromJson', function() {
  var postStream = buildStream(1231);

  postStream.updateFromJson({
    posts: [{id: 1}],
    stream: [1],
    extra_property: 12
  });

  equal(postStream.get('posts.length'), 1, 'it loaded the posts');
  containsInstance(postStream.get('posts'), Discourse.Post);

  equal(postStream.get('extra_property'), 12);
});

test("removePosts", function() {
  var postStream = buildStream(10000001, [1,2,3]);

  var p1 = Discourse.Post.create({id: 1, post_number: 2}),
      p2 = Discourse.Post.create({id: 2, post_number: 3}),
      p3 = Discourse.Post.create({id: 3, post_number: 4});

  postStream.appendPost(p1);
  postStream.appendPost(p2);
  postStream.appendPost(p3);

  // Removing nothing does nothing
  postStream.removePosts();
  equal(postStream.get('posts.length'), 3);

  postStream.removePosts([p1, p3]);
  equal(postStream.get('posts.length'), 1);
  deepEqual(postStream.get('stream'), [2]);

});

test("cancelFilter", function() {
  var postStream = buildStream(1235);

  sandbox.stub(postStream, "refresh");

  postStream.set('summary', true);
  postStream.cancelFilter();
  ok(!postStream.get('summary'), "summary is cancelled");

  postStream.toggleParticipant(participant);
  postStream.cancelFilter();
  blank(postStream.get('userFilters'), "cancelling the filters clears the userFilters");
});

test("toggleParticipant", function() {
  var postStream = buildStream(1236);
  sandbox.stub(postStream, "refresh");

  equal(postStream.get('userFilters.length'), 0, "by default no participants are toggled");

  postStream.toggleParticipant(participant.username);
  ok(postStream.get('userFilters').contains('eviltrout'), 'eviltrout is in the filters');

  postStream.toggleParticipant(participant.username);
  blank(postStream.get('userFilters'), "toggling the participant again removes them");
});

test("streamFilters", function() {
  var postStream = buildStream(1237);
  sandbox.stub(postStream, "refresh");

  deepEqual(postStream.get('streamFilters'), {}, "there are no postFilters by default");
  ok(postStream.get('hasNoFilters'), "there are no filters by default");

  postStream.set('summary', true);
  deepEqual(postStream.get('streamFilters'), {filter: "summary"}, "postFilters contains the summary flag");
  ok(!postStream.get('hasNoFilters'), "now there are filters present");

  postStream.toggleParticipant(participant.username);
  deepEqual(postStream.get('streamFilters'), {
    username_filters: 'eviltrout',
    show_deleted: true
  }, "streamFilters contains the username we filtered and show_deleted");

  postStream.toggleDeleted();
  deepEqual(postStream.get('streamFilters'), {
    username_filters: 'eviltrout'
  }, "streamFilters contains the username we filtered without show_deleted");

  postStream.cancelFilter();
  postStream.toggleDeleted();
  deepEqual(postStream.get('streamFilters'), {
    show_deleted: true
  }, "streamFilters show_deleted only");

});

test("loading", function() {
  var postStream = buildStream(1234);
  ok(!postStream.get('loading'), "we're not loading by default");

  postStream.set('loadingAbove', true);
  ok(postStream.get('loading'), "we're loading if loading above");

  postStream = buildStream(1234);
  postStream.set('loadingBelow', true);
  ok(postStream.get('loading'), "we're loading if loading below");

  postStream = buildStream(1234);
  postStream.set('loadingFilter', true);
  ok(postStream.get('loading'), "we're loading if loading a filter");
});

test("nextWindow", function() {
  Discourse.SiteSettings.posts_chunksize = 5;
  var postStream = buildStream(1234, [1,2,3,5,8,9,10,11,13,14,15,16]);

  blank(postStream.get('nextWindow'), 'With no posts loaded, the window is blank');

  postStream.updateFromJson({ posts: [{id: 1}, {id: 2}] });
  deepEqual(postStream.get('nextWindow'), [3,5,8,9,10],
            "If we've loaded the first 2 posts, the window should be the 5 after that");

  postStream.updateFromJson({ posts: [{id: 13}] });
  deepEqual(postStream.get('nextWindow'), [14, 15, 16], "Boundary check: stop at the end.");

  postStream.updateFromJson({ posts: [{id: 16}] });
  blank(postStream.get('nextWindow'), "Once we've seen everything there's nothing to load.");
});

test("previousWindow", function() {
  Discourse.SiteSettings.posts_chunksize = 5;
  var postStream = buildStream(1234, [1,2,3,5,8,9,10,11,13,14,15,16]);

  blank(postStream.get('previousWindow'), 'With no posts loaded, the window is blank');

  postStream.updateFromJson({ posts: [{id: 11}, {id: 13}] });
  deepEqual(postStream.get('previousWindow'), [3, 5, 8, 9, 10],
            "If we've loaded in the middle, it's the previous 5 posts");

  postStream.updateFromJson({ posts: [{id: 3}] });
  deepEqual(postStream.get('previousWindow'), [1, 2], "Boundary check: stop at the beginning.");

  postStream.updateFromJson({ posts: [{id: 1}] });
  blank(postStream.get('previousWindow'), "Once we've seen everything there's nothing to load.");
});

test("storePost", function() {
  var postStream = buildStream(1234),
      post = Discourse.Post.create({id: 1, post_number: 100, raw: 'initial value'});

  blank(postStream.get('topic.highest_post_number'), "it has no highest post number yet");
  var stored = postStream.storePost(post);
  equal(post, stored, "it returns the post it stored");
  equal(post.get('topic'), postStream.get('topic'), "it creates the topic reference properly");
  equal(postStream.get('topic.highest_post_number'), 100, "it set the highest post number");

  var dupePost = Discourse.Post.create({id: 1, post_number: 100, raw: 'updated value'});
  var storedDupe = postStream.storePost(dupePost);
  equal(storedDupe, post, "it returns the previously stored post instead to avoid dupes");
  equal(storedDupe.get('raw'), 'updated value', 'it updates the previously stored post');

  var postWithoutId = Discourse.Post.create({raw: 'hello world'});
  stored = postStream.storePost(postWithoutId);
  equal(stored, postWithoutId, "it returns the same post back");
  equal(postStream.get('postIdentityMap.length'), 1, "it does not add a new entry into the identity map");

});

test("identity map", function() {
  var postStream = buildStream(1234);
  var p1 = postStream.appendPost(Discourse.Post.create({id: 1, post_number: 1}));
  postStream.appendPost(Discourse.Post.create({id: 3, post_number: 4}));

  equal(postStream.findLoadedPost(1), p1, "it can return cached posts by id");
  blank(postStream.findLoadedPost(4), "it can't find uncached posts");

  deepEqual(postStream.listUnloadedIds([10, 11, 12]), [10, 11, 12], "it returns a list of all unloaded ids");
  blank(postStream.listUnloadedIds([1, 3]), "if we have loaded all posts it's blank");
  deepEqual(postStream.listUnloadedIds([1, 2, 3, 4]), [2, 4], "it only returns unloaded posts");
});

asyncTestDiscourse("loadIntoIdentityMap with no data", function() {
  var postStream = buildStream(1234);
  expect(1);

  sandbox.stub(Discourse, "ajax");
  postStream.loadIntoIdentityMap([]).then(function() {
    ok(!Discourse.ajax.calledOnce, "an empty array returned a promise yet performed no ajax request");
    start();
  });
});

asyncTestDiscourse("loadIntoIdentityMap with post ids", function() {
  var postStream = buildStream(1234);
  expect(1);

  sandbox.stub(Discourse, "ajax").returns(Ember.RSVP.resolve({
    post_stream: {
      posts: [{id: 10, post_number: 10}]
    }
  }));

  postStream.loadIntoIdentityMap([10]).then(function() {
    present(postStream.findLoadedPost(10), "it adds the returned post to the store");
    start();
  });
});

asyncTestDiscourse("loading a post's history", function() {
  var postStream = buildStream(1234);
  expect(3);

  var post = Discourse.Post.create({id: 4321});

  var secondPost = Discourse.Post.create({id: 2222});

  sandbox.stub(Discourse, "ajax").returns(Ember.RSVP.resolve([secondPost]));
  postStream.findReplyHistory(post).then(function() {
    ok(Discourse.ajax.calledOnce, "it made the ajax request");
    present(postStream.findLoadedPost(2222), "it stores the returned post in the identity map");
    present(post.get('replyHistory'), "it sets the replyHistory attribute for the post");
    start();
  });
});

test("staging and undoing a new post", function() {
  var postStream = buildStream(10101, [1]);
  postStream.appendPost(Discourse.Post.create({id: 1, post_number: 1}));

  var user = Discourse.User.create({username: 'eviltrout', name: 'eviltrout', id: 321});
  var stagedPost = Discourse.Post.create({ raw: 'hello world this is my new post' });

  var topic = postStream.get('topic');
  topic.setProperties({
    posts_count: 1,
    highest_post_number: 1
  });

  // Stage the new post in the stream
  var result = postStream.stagePost(stagedPost, user);
  equal(result, true, "it returns true");
  equal(topic.get('highest_post_number'), 2, "it updates the highest_post_number");
  ok(postStream.get('loading'), "it is loading while the post is being staged");

  equal(topic.get('posts_count'), 2, "it increases the post count");
  present(topic.get('last_posted_at'), "it updates last_posted_at");
  equal(topic.get('details.last_poster'), user, "it changes the last poster");

  equal(stagedPost.get('topic'), topic, "it assigns the topic reference");
  equal(stagedPost.get('post_number'), 2, "it is assigned the probable post_number");
  present(stagedPost.get('created_at'), "it is assigned a created date");
  ok(postStream.get('posts').contains(stagedPost), "the post is added to the stream");
  equal(stagedPost.get('id'), -1, "the post has a magical -1 id");

  // Undoing a created post (there was an error)
  postStream.undoPost(stagedPost);

  ok(!postStream.get('loading'), "it is no longer loading");
  equal(topic.get('highest_post_number'), 1, "it reverts the highest_post_number");
  equal(topic.get('posts_count'), 1, "it reverts the post count");
  equal(postStream.get('filteredPostsCount'), 1, "it retains the filteredPostsCount");
  ok(!postStream.get('posts').contains(stagedPost), "the post is removed from the stream");
});

test("staging and committing a post", function() {
  var postStream = buildStream(10101, [1]);
  postStream.appendPost(Discourse.Post.create({id: 1, post_number: 1}));
  var user = Discourse.User.create({username: 'eviltrout', name: 'eviltrout', id: 321});
  var stagedPost = Discourse.Post.create({ raw: 'hello world this is my new post' });

  var topic = postStream.get('topic');
  topic.set('posts_count', 1);

  // Stage the new post in the stream
  var result = postStream.stagePost(stagedPost, user);
  equal(result, true, "it returns true");

  ok(postStream.get('loading'), "it is loading while the post is being staged");
  stagedPost.setProperties({ id: 1234, raw: "different raw value" });

  result = postStream.stagePost(stagedPost, user);
  equal(result, false, "you can't stage a post while it is currently staging");

  postStream.commitPost(stagedPost);
  ok(postStream.get('posts').contains(stagedPost), "the post is still in the stream");
  ok(!postStream.get('loading'), "it is no longer loading");
  equal(postStream.get('filteredPostsCount'), 2, "it increases the filteredPostsCount");

  var found = postStream.findLoadedPost(stagedPost.get('id'));
  present(found, "the post is in the identity map");
  ok(postStream.indexOf(stagedPost) > -1, "the post is in the stream");
  equal(found.get('raw'), 'different raw value', 'it also updated the value in the stream');

});

test('triggerNewPostInStream', function() {
  var postStream = buildStream(225566);

  sandbox.stub(postStream, 'appendMore');
  sandbox.stub(postStream, 'refresh');

  postStream.triggerNewPostInStream(null);
  ok(!postStream.appendMore.calledOnce, "asking for a null id does nothing");

  postStream.toggleSummary();
  postStream.triggerNewPostInStream(1);
  ok(!postStream.appendMore.calledOnce, "it will not trigger when summary is active");

  postStream.cancelFilter();
  postStream.toggleParticipant('eviltrout');
  postStream.triggerNewPostInStream(1);
  ok(!postStream.appendMore.calledOnce, "it will not trigger when a participant filter is active");

  postStream.cancelFilter();
  postStream.triggerNewPostInStream(1);
  ok(!postStream.appendMore.calledOnce, "it wont't delegate to appendMore because the last post is not loaded");

  postStream.cancelFilter();
  postStream.appendPost(Discourse.Post.create({id: 1, post_number: 2}));
  postStream.triggerNewPostInStream(2);
  ok(postStream.appendMore.calledOnce, "delegates to appendMore because the last post is loaded");
});


test("loadedAllPosts when the id changes", function() {
  // This can happen in a race condition between staging a post and it coming through on the
  // message bus. If the id of a post changes we should reconsider the loadedAllPosts property.
  var postStream = buildStream(10101, [1, 2]);
  var postWithoutId = Discourse.Post.create({ raw: 'hello world this is my new post' });

  postStream.appendPost(Discourse.Post.create({id: 1, post_number: 1}));
  postStream.appendPost(postWithoutId);
  ok(!postStream.get('loadedAllPosts'), 'the last post is not loaded');

  postWithoutId.set('id', 2);
  ok(postStream.get('loadedAllPosts'), 'the last post is loaded now that the post has an id');
});

test("comitting and triggerNewPostInStream race condition", function() {
  var postStream = buildStream(4964);

  postStream.appendPost(Discourse.Post.create({id: 1, post_number: 1}));
  var user = Discourse.User.create({username: 'eviltrout', name: 'eviltrout', id: 321});
  var stagedPost = Discourse.Post.create({ raw: 'hello world this is my new post' });

  postStream.stagePost(stagedPost, user);
  equal(postStream.get('filteredPostsCount'), 0, "it has no filteredPostsCount yet");
  stagedPost.set('id', 123);

  sandbox.stub(postStream, 'appendMore');
  postStream.triggerNewPostInStream(123);
  equal(postStream.get('filteredPostsCount'), 1, "it added the post");

  postStream.commitPost(stagedPost);
  equal(postStream.get('filteredPostsCount'), 1, "it does not add the same post twice");
});

