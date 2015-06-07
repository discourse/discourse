import DiscourseController from 'discourse/controllers/controller';
import Presence from 'discourse/mixins/presence';

module("DiscourseController");

test("includes mixins", function() {
  ok(Presence.detect(DiscourseController.create()), "has Presence");
});
