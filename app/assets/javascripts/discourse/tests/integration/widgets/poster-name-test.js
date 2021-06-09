import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  exists,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule(
  "Integration | Component | Widget | poster-name",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("basic rendering", {
      template: hbs`{{mount-widget widget="poster-name" args=args}}`,
      beforeEach() {
        this.set("args", {
          username: "eviltrout",
          usernameUrl: "/u/eviltrout",
          name: "Robin Ward",
          user_title: "Trout Master",
        });
      },
      test(assert) {
        assert.ok(exists(".names"));
        assert.ok(exists("span.username"));
        assert.ok(exists('a[data-user-card="eviltrout"]'));
        assert.equal(queryAll(".username a").text(), "eviltrout");
        assert.equal(queryAll(".full-name a").text(), "Robin Ward");
        assert.equal(queryAll(".user-title").text(), "Trout Master");
      },
    });

    componentTest("extra classes and glyphs", {
      template: hbs`{{mount-widget widget="poster-name" args=args}}`,
      beforeEach() {
        this.set("args", {
          username: "eviltrout",
          usernameUrl: "/u/eviltrout",
          staff: true,
          admin: true,
          moderator: true,
          new_user: true,
          primary_group_name: "fish",
        });
      },
      test(assert) {
        assert.ok(exists("span.staff"));
        assert.ok(exists("span.admin"));
        assert.ok(exists("span.moderator"));
        assert.ok(exists(".d-icon-shield-alt"));
        assert.ok(exists("span.new-user"));
        assert.ok(exists("span.fish"));
      },
    });

    componentTest("disable display name on posts", {
      template: hbs`{{mount-widget widget="poster-name" args=args}}`,
      beforeEach() {
        this.siteSettings.display_name_on_posts = false;
        this.set("args", { username: "eviltrout", name: "Robin Ward" });
      },
      test(assert) {
        assert.ok(!exists(".full-name"));
      },
    });

    componentTest("doesn't render a name if it's similar to the username", {
      template: hbs`{{mount-widget widget="poster-name" args=args}}`,
      beforeEach() {
        this.siteSettings.prioritize_username_in_ux = true;
        this.siteSettings.display_name_on_posts = true;
        this.set("args", { username: "eviltrout", name: "evil-trout" });
      },
      test(assert) {
        assert.ok(!exists(".second"));
      },
    });
  }
);
