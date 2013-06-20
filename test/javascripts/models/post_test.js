module("Discourse.Post");

test('new_user', function() {
  var post = Discourse.Post.create({trust_level: 0});
  ok(post.get('new_user'), "post is from a new user");

  post.set('trust_level', 1);
  ok(!post.get('new_user'), "post is no longer from a new user");
});

test('firstPost', function() {
  var post = Discourse.Post.create({post_number: 1});
  ok(post.get('firstPost'), "it's the first post");

  post.set('post_number', 10);
  ok(!post.get('firstPost'), "post is no longer the first post");
});


test('updateFromPost', function() {
  var post = Discourse.Post.create({
    post_number: 1,
    raw: 'hello world'
  });

  post.updateFromPost(Discourse.Post.create({
    raw: 'different raw',
    wat: function() { return 123; }
  }));

  equal(post.get('raw'), "different raw", "raw field updated");
});