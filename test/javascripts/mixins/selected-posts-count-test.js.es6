module("mixin:selected-posts-count");

import SelectedPostsCount from 'discourse/mixins/selected-posts-count';
import Topic from 'discourse/models/topic';

var buildTestObj = function(params) {
  return Ember.Object.extend(SelectedPostsCount).create(params || {});
};

test("without selectedPosts", function () {
  var testObj = buildTestObj();

  equal(testObj.get('selectedPostsCount'), 0, "No posts are selected without a selectedPosts property");

  testObj.set('selectedPosts', []);
  equal(testObj.get('selectedPostsCount'), 0, "No posts are selected when selectedPosts is an empty array");
});

test("with some selectedPosts", function() {
  var testObj = buildTestObj({ selectedPosts: [Discourse.Post.create({id: 123})] });
  equal(testObj.get('selectedPostsCount'), 1, "It returns the amount of posts");
});

test("when all posts are selected and there is a posts_count", function() {
  var testObj = buildTestObj({ allPostsSelected: true, posts_count: 1024 });
  equal(testObj.get('selectedPostsCount'), 1024, "It returns the posts_count");
});

test("when all posts are selected and there is topic with a posts_count", function() {
  var testObj = buildTestObj({
    allPostsSelected: true,
    topic: Topic.create({ posts_count: 3456 })
   });

  equal(testObj.get('selectedPostsCount'), 3456, "It returns the topic's posts_count");
});
