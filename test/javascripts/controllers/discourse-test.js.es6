import DiscourseController from 'discourse/controllers/controller';

module("DiscourseController");

test("includes mixins", function() {
  ok(Discourse.Presence.detect(DiscourseController.create()), "Discourse.Presence");
  ok(Discourse.HasCurrentUser.detect(DiscourseController.create()), "Discourse.HasCurrentUser");
});
