import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule, exists } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule(
  "Integration | Component | Widget | topic-participant",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("one post", {
      template: hbs`{{mount-widget widget="topic-participant" args=args}}`,

      beforeEach() {
        this.set("args", {
          username: "test",
          avatar_template: "/images/avatar.png",
          post_count: 1,
        });
      },

      test(assert) {
        assert.ok(exists("a.poster.trigger-user-card"));
        assert.ok(
          !exists("span.post-count"),
          "don't show count for only 1 post"
        );
        assert.ok(!exists(".avatar-flair"), "no avatar flair");
      },
    });

    componentTest("many posts, a primary group with flair", {
      template: hbs`{{mount-widget widget="topic-participant" args=args}}`,

      beforeEach() {
        this.set("args", {
          username: "test",
          avatar_template: "/images/avatar.png",
          post_count: 5,
          primary_group_name: "devs",
          flair_name: "devs",
          flair_url: "/images/d-logo-sketch-small.png",
          flair_bg_color: "222",
        });
      },

      test(assert) {
        assert.ok(exists("a.poster.trigger-user-card"));
        assert.ok(exists("span.post-count"), "show count for many posts");
        assert.ok(
          exists(".group-devs a.poster"),
          "add class for the group outside the link"
        );
        assert.ok(
          exists(".avatar-flair.avatar-flair-devs"),
          "show flair with group class"
        );
      },
    });
  }
);
