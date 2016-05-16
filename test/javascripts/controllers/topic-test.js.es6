import { blank, present } from 'helpers/qunit-helpers';

moduleFor('controller:topic', 'controller:topic', {
  needs: ['controller:modal', 'controller:composer', 'controller:quote-button',
          'controller:application']
});

import Topic from 'discourse/models/topic';
import AppEvents from 'discourse/lib/app-events';

var buildTopic = function() {
  return Topic.create({
    title: "Qunit Test Topic",
    participants: [
      {id: 1234,
       post_count: 4,
       username: "eviltrout"}
    ]
  });
};


test("editingMode", function() {
  var topic = buildTopic(),
      topicController = this.subject({model: topic});

  ok(!topicController.get('editingTopic'), "we are not editing by default");

  topicController.set('model.details.can_edit', false);
  topicController.send('editTopic');
  ok(!topicController.get('editingTopic'), "calling editTopic doesn't enable editing unless the user can edit");

  topicController.set('model.details.can_edit', true);
  topicController.send('editTopic');
  ok(topicController.get('editingTopic'), "calling editTopic enables editing if the user can edit");
  equal(topicController.get('buffered.title'), topic.get('title'));
  equal(topicController.get('buffered.category_id'), topic.get('category_id'));

  topicController.send('cancelEditingTopic');
  ok(!topicController.get('editingTopic'), "cancelling edit mode reverts the property value");
});

test("toggledSelectedPost", function() {
  var tc = this.subject({ model: buildTopic() }),
      post = Discourse.Post.create({id: 123, post_number: 2}),
      postStream = tc.get('model.postStream');

  postStream.appendPost(post);
  postStream.appendPost(Discourse.Post.create({id: 124, post_number: 3}));

  blank(tc.get('selectedPosts'), "there are no selected posts by default");
  equal(tc.get('selectedPostsCount'), 0, "there is a selected post count of 0");
  ok(!tc.postSelected(post), "the post is not selected by default");

  tc.send('toggledSelectedPost', post);
  present(tc.get('selectedPosts'), "there is a selectedPosts collection");
  equal(tc.get('selectedPostsCount'), 1, "there is a selected post now");
  ok(tc.postSelected(post), "the post is now selected");

  tc.send('toggledSelectedPost', post);
  ok(!tc.postSelected(post), "the post is no longer selected");

});

test("selectAll", function() {
  var tc = this.subject({model: buildTopic(), appEvents: AppEvents.create()}),
      post = Discourse.Post.create({id: 123, post_number: 2}),
      postStream = tc.get('model.postStream');

  postStream.appendPost(post);

  ok(!tc.postSelected(post), "the post is not selected by default");
  tc.send('selectAll');
  ok(tc.postSelected(post), "the post is now selected");
  ok(tc.get('allPostsSelected'), "all posts are selected");
  tc.send('deselectAll');
  ok(!tc.postSelected(post), "the post is deselected again");
  ok(!tc.get('allPostsSelected'), "all posts are not selected");

});

test("Automating setting of allPostsSelected", function() {
  var topic = buildTopic(),
      tc = this.subject({model: topic}),
      post = Discourse.Post.create({id: 123, post_number: 2}),
      postStream = tc.get('model.postStream');

  topic.set('posts_count', 1);
  postStream.appendPost(post);
  ok(!tc.get('allPostsSelected'), "all posts are not selected by default");

  tc.send('toggledSelectedPost', post);
  ok(tc.get('allPostsSelected'), "all posts are selected if we select the only post");

  tc.send('toggledSelectedPost', post);
  ok(!tc.get('allPostsSelected'), "the posts are no longer automatically selected");
});

test("Select Replies when present", function() {
  var topic = buildTopic(),
      tc = this.subject({ model: topic }),
      p1 = Discourse.Post.create({id: 1, post_number: 1, reply_count: 1}),
      p2 = Discourse.Post.create({id: 2, post_number: 2}),
      p3 = Discourse.Post.create({id: 2, post_number: 3, reply_to_post_number: 1});

  ok(!tc.postSelected(p3), "replies are not selected by default");
  tc.send('toggledSelectedPostReplies', p1);
  ok(tc.postSelected(p1), "it selects the post");
  ok(!tc.postSelected(p2), "it doesn't select a post that's not a reply");
  ok(tc.postSelected(p3), "it selects a post that is a reply");
  equal(tc.get('selectedPostsCount'), 2, "it has a selected posts count of two");

  // If we deselected the post whose replies are selected...
  tc.send('toggledSelectedPost', p1);
  ok(!tc.postSelected(p1), "it deselects the post");
  ok(!tc.postSelected(p3), "it deselects the replies too");

  // If we deselect a reply, it should deselect the parent's replies selected attribute. Weird but what else would make sense?
  tc.send('toggledSelectedPostReplies', p1);
  tc.send('toggledSelectedPost', p3);
  ok(tc.postSelected(p1), "the post stays selected");
  ok(!tc.postSelected(p3), "it deselects the replies too");

});

