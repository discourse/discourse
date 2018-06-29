QUnit.module("model:post-stream");

import createStore from "helpers/create-store";

const buildStream = function(id, stream) {
  const store = createStore();
  const topic = store.createRecord("topic", { id, chunk_size: 5 });
  const ps = topic.get("postStream");
  if (stream) {
    ps.set("stream", stream);
  }
  return ps;
};

const participant = { username: "eviltrout" };

QUnit.test("create", assert => {
  const store = createStore();
  assert.ok(
    store.createRecord("postStream"),
    "it can be created with no parameters"
  );
});

QUnit.test("defaults", assert => {
  const postStream = buildStream(1234);
  assert.blank(
    postStream.get("posts"),
    "there are no posts in a stream by default"
  );
  assert.ok(!postStream.get("loaded"), "it has never loaded");
  assert.present(postStream.get("topic"));
});

QUnit.test("appending posts", assert => {
  const postStream = buildStream(4567, [1, 3, 4]);
  const store = postStream.store;

  assert.equal(postStream.get("firstPostId"), 1);
  assert.equal(postStream.get("lastPostId"), 4, "the last post id is 4");

  assert.ok(!postStream.get("hasPosts"), "there are no posts by default");
  assert.ok(
    !postStream.get("firstPostPresent"),
    "the first post is not loaded"
  );
  assert.ok(!postStream.get("loadedAllPosts"), "the last post is not loaded");
  assert.equal(postStream.get("posts.length"), 0, "it has no posts initially");

  postStream.appendPost(store.createRecord("post", { id: 2, post_number: 2 }));
  assert.ok(
    !postStream.get("firstPostPresent"),
    "the first post is still not loaded"
  );
  assert.equal(
    postStream.get("posts.length"),
    1,
    "it has one post in the stream"
  );

  postStream.appendPost(store.createRecord("post", { id: 4, post_number: 4 }));
  assert.ok(
    !postStream.get("firstPostPresent"),
    "the first post is still loaded"
  );
  assert.ok(postStream.get("loadedAllPosts"), "the last post is now loaded");
  assert.equal(
    postStream.get("posts.length"),
    2,
    "it has two posts in the stream"
  );

  postStream.appendPost(store.createRecord("post", { id: 4, post_number: 4 }));
  assert.equal(
    postStream.get("posts.length"),
    2,
    "it will not add the same post with id twice"
  );

  const stagedPost = store.createRecord("post", { raw: "incomplete post" });
  postStream.appendPost(stagedPost);
  assert.equal(
    postStream.get("posts.length"),
    3,
    "it can handle posts without ids"
  );
  postStream.appendPost(stagedPost);
  assert.equal(
    postStream.get("posts.length"),
    3,
    "it won't add the same post without an id twice"
  );

  // change the stream
  postStream.set("stream", [1, 2, 4]);
  assert.ok(
    !postStream.get("firstPostPresent"),
    "the first post no longer loaded since the stream changed."
  );
  assert.ok(
    postStream.get("loadedAllPosts"),
    "the last post is still the last post in the new stream"
  );
});

QUnit.test("closestPostNumberFor", assert => {
  const postStream = buildStream(1231);
  const store = postStream.store;

  assert.blank(
    postStream.closestPostNumberFor(1),
    "there is no closest post when nothing is loaded"
  );

  postStream.appendPost(store.createRecord("post", { id: 1, post_number: 2 }));
  postStream.appendPost(store.createRecord("post", { id: 2, post_number: 3 }));

  assert.equal(
    postStream.closestPostNumberFor(2),
    2,
    "If a post is in the stream it returns its post number"
  );
  assert.equal(
    postStream.closestPostNumberFor(3),
    3,
    "If a post is in the stream it returns its post number"
  );
  assert.equal(
    postStream.closestPostNumberFor(10),
    3,
    "it clips to the upper bound of the stream"
  );
  assert.equal(
    postStream.closestPostNumberFor(0),
    2,
    "it clips to the lower bound of the stream"
  );
});

QUnit.test("closestDaysAgoFor", assert => {
  const postStream = buildStream(1231);
  postStream.set("timelineLookup", [[1, 10], [3, 8], [5, 1]]);

  assert.equal(postStream.closestDaysAgoFor(1), 10);
  assert.equal(postStream.closestDaysAgoFor(2), 10);
  assert.equal(postStream.closestDaysAgoFor(3), 8);
  assert.equal(postStream.closestDaysAgoFor(4), 8);
  assert.equal(postStream.closestDaysAgoFor(5), 1);

  // Out of bounds
  assert.equal(postStream.closestDaysAgoFor(-1), 10);
  assert.equal(postStream.closestDaysAgoFor(0), 10);
  assert.equal(postStream.closestDaysAgoFor(10), 1);
});

QUnit.test("closestDaysAgoFor - empty", assert => {
  const postStream = buildStream(1231);
  postStream.set("timelineLookup", []);

  assert.equal(postStream.closestDaysAgoFor(1), null);
});

QUnit.test("updateFromJson", assert => {
  const postStream = buildStream(1231);

  postStream.updateFromJson({
    posts: [{ id: 1 }],
    stream: [1],
    extra_property: 12
  });

  assert.equal(postStream.get("posts.length"), 1, "it loaded the posts");
  assert.containsInstance(postStream.get("posts"), Discourse.Post);

  assert.equal(postStream.get("extra_property"), 12);
});

QUnit.test("removePosts", assert => {
  const postStream = buildStream(10000001, [1, 2, 3]);
  const store = postStream.store;

  const p1 = store.createRecord("post", { id: 1, post_number: 2 }),
    p2 = store.createRecord("post", { id: 2, post_number: 3 }),
    p3 = store.createRecord("post", { id: 3, post_number: 4 });

  postStream.appendPost(p1);
  postStream.appendPost(p2);
  postStream.appendPost(p3);

  // Removing nothing does nothing
  postStream.removePosts();
  assert.equal(postStream.get("posts.length"), 3);

  postStream.removePosts([p1, p3]);
  assert.equal(postStream.get("posts.length"), 1);
  assert.deepEqual(postStream.get("stream"), [2]);
});

QUnit.test("cancelFilter", assert => {
  const postStream = buildStream(1235);

  sandbox.stub(postStream, "refresh").returns(new Ember.RSVP.resolve());

  postStream.set("summary", true);
  postStream.cancelFilter();
  assert.ok(!postStream.get("summary"), "summary is cancelled");

  postStream.toggleParticipant(participant);
  postStream.cancelFilter();
  assert.blank(
    postStream.get("userFilters"),
    "cancelling the filters clears the userFilters"
  );
});

QUnit.test("findPostIdForPostNumber", assert => {
  const postStream = buildStream(1234, [10, 20, 30, 40, 50, 60, 70]);
  postStream.set("gaps", { before: { 60: [55, 58] } });

  assert.equal(
    postStream.findPostIdForPostNumber(500),
    null,
    "it returns null when the post cannot be found"
  );
  assert.equal(
    postStream.findPostIdForPostNumber(1),
    10,
    "it finds the postId at the beginning"
  );
  assert.equal(
    postStream.findPostIdForPostNumber(5),
    50,
    "it finds the postId in the middle"
  );
  assert.equal(postStream.findPostIdForPostNumber(8), 60, "it respects gaps");
});

QUnit.test("toggleParticipant", assert => {
  const postStream = buildStream(1236);
  sandbox.stub(postStream, "refresh").returns(new Ember.RSVP.resolve());

  assert.equal(
    postStream.get("userFilters.length"),
    0,
    "by default no participants are toggled"
  );

  postStream.toggleParticipant(participant.username);
  assert.ok(
    postStream.get("userFilters").includes("eviltrout"),
    "eviltrout is in the filters"
  );

  postStream.toggleParticipant(participant.username);
  assert.blank(
    postStream.get("userFilters"),
    "toggling the participant again removes them"
  );
});

QUnit.test("streamFilters", assert => {
  const postStream = buildStream(1237);
  sandbox.stub(postStream, "refresh").returns(new Ember.RSVP.resolve());

  assert.deepEqual(
    postStream.get("streamFilters"),
    {},
    "there are no postFilters by default"
  );
  assert.ok(postStream.get("hasNoFilters"), "there are no filters by default");

  postStream.set("summary", true);
  assert.deepEqual(
    postStream.get("streamFilters"),
    { filter: "summary" },
    "postFilters contains the summary flag"
  );
  assert.ok(!postStream.get("hasNoFilters"), "now there are filters present");

  postStream.toggleParticipant(participant.username);
  assert.deepEqual(
    postStream.get("streamFilters"),
    {
      username_filters: "eviltrout"
    },
    "streamFilters contains the username we filtered"
  );
});

QUnit.test("loading", assert => {
  let postStream = buildStream(1234);
  assert.ok(!postStream.get("loading"), "we're not loading by default");

  postStream.set("loadingAbove", true);
  assert.ok(postStream.get("loading"), "we're loading if loading above");

  postStream = buildStream(1234);
  postStream.set("loadingBelow", true);
  assert.ok(postStream.get("loading"), "we're loading if loading below");

  postStream = buildStream(1234);
  postStream.set("loadingFilter", true);
  assert.ok(postStream.get("loading"), "we're loading if loading a filter");
});

QUnit.test("nextWindow", assert => {
  const postStream = buildStream(1234, [
    1,
    2,
    3,
    5,
    8,
    9,
    10,
    11,
    13,
    14,
    15,
    16
  ]);

  assert.blank(
    postStream.get("nextWindow"),
    "With no posts loaded, the window is blank"
  );

  postStream.updateFromJson({ posts: [{ id: 1 }, { id: 2 }] });
  assert.deepEqual(
    postStream.get("nextWindow"),
    [3, 5, 8, 9, 10],
    "If we've loaded the first 2 posts, the window should be the 5 after that"
  );

  postStream.updateFromJson({ posts: [{ id: 13 }] });
  assert.deepEqual(
    postStream.get("nextWindow"),
    [14, 15, 16],
    "Boundary check: stop at the end."
  );

  postStream.updateFromJson({ posts: [{ id: 16 }] });
  assert.blank(
    postStream.get("nextWindow"),
    "Once we've seen everything there's nothing to load."
  );
});

QUnit.test("previousWindow", assert => {
  const postStream = buildStream(1234, [
    1,
    2,
    3,
    5,
    8,
    9,
    10,
    11,
    13,
    14,
    15,
    16
  ]);

  assert.blank(
    postStream.get("previousWindow"),
    "With no posts loaded, the window is blank"
  );

  postStream.updateFromJson({ posts: [{ id: 11 }, { id: 13 }] });
  assert.deepEqual(
    postStream.get("previousWindow"),
    [3, 5, 8, 9, 10],
    "If we've loaded in the middle, it's the previous 5 posts"
  );

  postStream.updateFromJson({ posts: [{ id: 3 }] });
  assert.deepEqual(
    postStream.get("previousWindow"),
    [1, 2],
    "Boundary check: stop at the beginning."
  );

  postStream.updateFromJson({ posts: [{ id: 1 }] });
  assert.blank(
    postStream.get("previousWindow"),
    "Once we've seen everything there's nothing to load."
  );
});

QUnit.test("storePost", assert => {
  const postStream = buildStream(1234),
    store = postStream.store,
    post = store.createRecord("post", {
      id: 1,
      post_number: 100,
      raw: "initial value"
    });

  assert.blank(
    postStream.get("topic.highest_post_number"),
    "it has no highest post number yet"
  );
  let stored = postStream.storePost(post);
  assert.equal(post, stored, "it returns the post it stored");
  assert.equal(
    post.get("topic"),
    postStream.get("topic"),
    "it creates the topic reference properly"
  );
  assert.equal(
    postStream.get("topic.highest_post_number"),
    100,
    "it set the highest post number"
  );

  const dupePost = store.createRecord("post", {
    id: 1,
    post_number: 100,
    raw: "updated value"
  });
  const storedDupe = postStream.storePost(dupePost);
  assert.equal(
    storedDupe,
    post,
    "it returns the previously stored post instead to avoid dupes"
  );
  assert.equal(
    storedDupe.get("raw"),
    "updated value",
    "it updates the previously stored post"
  );

  const postWithoutId = store.createRecord("post", { raw: "hello world" });
  stored = postStream.storePost(postWithoutId);
  assert.equal(stored, postWithoutId, "it returns the same post back");
});

QUnit.test("identity map", assert => {
  const postStream = buildStream(1234);
  const store = postStream.store;

  const p1 = postStream.appendPost(
    store.createRecord("post", { id: 1, post_number: 1 })
  );
  const p3 = postStream.appendPost(
    store.createRecord("post", { id: 3, post_number: 4 })
  );

  assert.equal(
    postStream.findLoadedPost(1),
    p1,
    "it can return cached posts by id"
  );
  assert.blank(postStream.findLoadedPost(4), "it can't find uncached posts");

  // Find posts by ids uses the identity map
  return postStream.findPostsByIds([1, 2, 3]).then(result => {
    assert.equal(result.length, 3);
    assert.equal(result.objectAt(0), p1);
    assert.equal(result.objectAt(1).get("post_number"), 2);
    assert.equal(result.objectAt(2), p3);
  });
});

QUnit.test("loadIntoIdentityMap with no data", assert => {
  return buildStream(1234)
    .loadIntoIdentityMap([])
    .then(result => {
      assert.equal(result.length, 0, "requesting no posts produces no posts");
    });
});

QUnit.test("loadIntoIdentityMap with post ids", assert => {
  const postStream = buildStream(1234);

  return postStream.loadIntoIdentityMap([10]).then(function() {
    assert.present(
      postStream.findLoadedPost(10),
      "it adds the returned post to the store"
    );
  });
});

QUnit.test("staging and undoing a new post", assert => {
  const postStream = buildStream(10101, [1]);
  const store = postStream.store;

  const original = store.createRecord("post", {
    id: 1,
    post_number: 1,
    topic_id: 10101
  });
  postStream.appendPost(original);
  assert.ok(
    postStream.get("lastAppended"),
    original,
    "the original post is lastAppended"
  );

  const user = Discourse.User.create({
    username: "eviltrout",
    name: "eviltrout",
    id: 321
  });
  const stagedPost = store.createRecord("post", {
    raw: "hello world this is my new post",
    topic_id: 10101
  });

  const topic = postStream.get("topic");
  topic.setProperties({
    posts_count: 1,
    highest_post_number: 1
  });

  // Stage the new post in the stream
  const result = postStream.stagePost(stagedPost, user);
  assert.equal(result, "staged", "it returns staged");
  assert.equal(
    topic.get("highest_post_number"),
    2,
    "it updates the highest_post_number"
  );
  assert.ok(
    postStream.get("loading"),
    "it is loading while the post is being staged"
  );
  assert.ok(
    postStream.get("lastAppended"),
    original,
    "it doesn't consider staged posts as the lastAppended"
  );

  assert.equal(topic.get("posts_count"), 2, "it increases the post count");
  assert.present(topic.get("last_posted_at"), "it updates last_posted_at");
  assert.equal(
    topic.get("details.last_poster"),
    user,
    "it changes the last poster"
  );

  assert.equal(
    stagedPost.get("topic"),
    topic,
    "it assigns the topic reference"
  );
  assert.equal(
    stagedPost.get("post_number"),
    2,
    "it is assigned the probable post_number"
  );
  assert.present(stagedPost.get("created_at"), "it is assigned a created date");
  assert.ok(
    postStream.get("posts").includes(stagedPost),
    "the post is added to the stream"
  );
  assert.equal(stagedPost.get("id"), -1, "the post has a magical -1 id");

  // Undoing a created post (there was an error)
  postStream.undoPost(stagedPost);

  assert.ok(!postStream.get("loading"), "it is no longer loading");
  assert.equal(
    topic.get("highest_post_number"),
    1,
    "it reverts the highest_post_number"
  );
  assert.equal(topic.get("posts_count"), 1, "it reverts the post count");
  assert.equal(
    postStream.get("filteredPostsCount"),
    1,
    "it retains the filteredPostsCount"
  );
  assert.ok(
    !postStream.get("posts").includes(stagedPost),
    "the post is removed from the stream"
  );
  assert.ok(
    postStream.get("lastAppended"),
    original,
    "it doesn't consider undid post lastAppended"
  );
});

QUnit.test("staging and committing a post", assert => {
  const postStream = buildStream(10101, [1]);
  const store = postStream.store;

  const original = store.createRecord("post", {
    id: 1,
    post_number: 1,
    topic_id: 10101
  });
  postStream.appendPost(original);
  assert.ok(
    postStream.get("lastAppended"),
    original,
    "the original post is lastAppended"
  );

  const user = Discourse.User.create({
    username: "eviltrout",
    name: "eviltrout",
    id: 321
  });
  const stagedPost = store.createRecord("post", {
    raw: "hello world this is my new post",
    topic_id: 10101
  });

  const topic = postStream.get("topic");
  topic.set("posts_count", 1);

  // Stage the new post in the stream
  let result = postStream.stagePost(stagedPost, user);
  assert.equal(result, "staged", "it returns staged");

  assert.ok(
    postStream.get("loading"),
    "it is loading while the post is being staged"
  );
  stagedPost.setProperties({ id: 1234, raw: "different raw value" });

  result = postStream.stagePost(stagedPost, user);
  assert.equal(
    result,
    "alreadyStaging",
    "you can't stage a post while it is currently staging"
  );
  assert.ok(
    postStream.get("lastAppended"),
    original,
    "staging a post doesn't change the lastAppended"
  );

  postStream.commitPost(stagedPost);
  assert.ok(
    postStream.get("posts").includes(stagedPost),
    "the post is still in the stream"
  );
  assert.ok(!postStream.get("loading"), "it is no longer loading");

  assert.equal(
    postStream.get("filteredPostsCount"),
    2,
    "it increases the filteredPostsCount"
  );

  const found = postStream.findLoadedPost(stagedPost.get("id"));
  assert.present(found, "the post is in the identity map");
  assert.ok(postStream.indexOf(stagedPost) > -1, "the post is in the stream");
  assert.equal(
    found.get("raw"),
    "different raw value",
    "it also updated the value in the stream"
  );
  assert.ok(
    postStream.get("lastAppended"),
    found,
    "comitting a post changes lastAppended"
  );
});

QUnit.test("loadedAllPosts when the id changes", assert => {
  // This can happen in a race condition between staging a post and it coming through on the
  // message bus. If the id of a post changes we should reconsider the loadedAllPosts property.
  const postStream = buildStream(10101, [1, 2]);
  const store = postStream.store;
  const postWithoutId = store.createRecord("post", {
    raw: "hello world this is my new post"
  });

  postStream.appendPost(store.createRecord("post", { id: 1, post_number: 1 }));
  postStream.appendPost(postWithoutId);
  assert.ok(!postStream.get("loadedAllPosts"), "the last post is not loaded");

  postWithoutId.set("id", 2);
  assert.ok(
    postStream.get("loadedAllPosts"),
    "the last post is loaded now that the post has an id"
  );
});

QUnit.test("triggerRecoveredPost", async assert => {
  const postStream = buildStream(4567);
  const store = postStream.store;

  [1, 2, 3, 5].forEach(id => {
    postStream.appendPost(
      store.createRecord("post", { id: id, post_number: id })
    );
  });

  const response = object => {
    return [200, { "Content-Type": "application/json" }, object];
  };

  // prettier-ignore
  server.get("/posts/4", () => { // eslint-disable-line no-undef
    return response({ id: 4, post_number: 4 });
  });

  assert.equal(
    postStream.get("postsWithPlaceholders.length"),
    4,
    "it should return the right length"
  );

  await postStream.triggerRecoveredPost(4);

  assert.equal(
    postStream.get("postsWithPlaceholders.length"),
    5,
    "it should return the right length"
  );
});

QUnit.test("comitting and triggerNewPostInStream race condition", assert => {
  const postStream = buildStream(4964);
  const store = postStream.store;

  postStream.appendPost(store.createRecord("post", { id: 1, post_number: 1 }));
  const user = Discourse.User.create({
    username: "eviltrout",
    name: "eviltrout",
    id: 321
  });
  const stagedPost = store.createRecord("post", {
    raw: "hello world this is my new post"
  });

  postStream.stagePost(stagedPost, user);
  assert.equal(
    postStream.get("filteredPostsCount"),
    0,
    "it has no filteredPostsCount yet"
  );
  stagedPost.set("id", 123);

  sandbox.stub(postStream, "appendMore");
  postStream.triggerNewPostInStream(123);
  assert.equal(postStream.get("filteredPostsCount"), 1, "it added the post");

  postStream.commitPost(stagedPost);
  assert.equal(
    postStream.get("filteredPostsCount"),
    1,
    "it does not add the same post twice"
  );
});

QUnit.test("postsWithPlaceholders", assert => {
  const postStream = buildStream(4964, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
  const postsWithPlaceholders = postStream.get("postsWithPlaceholders");
  const store = postStream.store;

  const testProxy = Ember.ArrayProxy.create({ content: postsWithPlaceholders });

  const p1 = store.createRecord("post", { id: 1, post_number: 1 });
  const p2 = store.createRecord("post", { id: 2, post_number: 2 });
  const p3 = store.createRecord("post", { id: 3, post_number: 3 });
  const p4 = store.createRecord("post", { id: 4, post_number: 4 });

  postStream.appendPost(p1);
  postStream.appendPost(p2);
  postStream.appendPost(p3);

  // Test enumerable and array access
  assert.equal(postsWithPlaceholders.get("length"), 3);
  assert.equal(testProxy.get("length"), 3);
  assert.equal(postsWithPlaceholders.nextObject(0), p1);
  assert.equal(postsWithPlaceholders.objectAt(0), p1);
  assert.equal(postsWithPlaceholders.nextObject(1, p1), p2);
  assert.equal(postsWithPlaceholders.objectAt(1), p2);
  assert.equal(postsWithPlaceholders.nextObject(2, p2), p3);
  assert.equal(postsWithPlaceholders.objectAt(2), p3);

  const promise = postStream.appendMore();
  assert.equal(
    postsWithPlaceholders.get("length"),
    8,
    "we immediately have a larger placeholder window"
  );
  assert.equal(testProxy.get("length"), 8);
  assert.ok(!!postsWithPlaceholders.nextObject(3, p3));
  assert.ok(!!postsWithPlaceholders.objectAt(4));
  assert.ok(postsWithPlaceholders.objectAt(3) !== p4);
  assert.ok(testProxy.objectAt(3) !== p4);

  return promise.then(() => {
    assert.equal(postsWithPlaceholders.objectAt(3), p4);
    assert.equal(
      postsWithPlaceholders.get("length"),
      8,
      "have a larger placeholder window when loaded"
    );
    assert.equal(testProxy.get("length"), 8);
    assert.equal(testProxy.objectAt(3), p4);
  });
});
