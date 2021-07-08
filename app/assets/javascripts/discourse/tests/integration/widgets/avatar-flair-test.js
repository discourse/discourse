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
  "Integration | Component | Widget | avatar-flair",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("avatar flair with an icon", {
      template: hbs`{{mount-widget widget="avatar-flair" args=args}}`,
      beforeEach() {
        this.set("args", {
          flair_url: "fa-bars",
          flair_bg_color: "CC0000",
          flair_color: "FFFFFF",
        });
      },
      test(assert) {
        assert.ok(exists(".avatar-flair"), "it has the tag");
        assert.ok(exists("svg.d-icon-bars"), "it has the svg icon");
        assert.equal(
          queryAll(".avatar-flair").attr("style"),
          "background-color: #CC0000; color: #FFFFFF; ",
          "it has styles"
        );
      },
    });

    componentTest("avatar flair with an image", {
      template: hbs`{{mount-widget widget="avatar-flair" args=args}}`,
      beforeEach() {
        this.set("args", {
          flair_url: "/images/avatar.png",
        });
      },
      test(assert) {
        assert.ok(exists(".avatar-flair"), "it has the tag");
        assert.ok(!exists("svg"), "it does not have an svg icon");
      },
    });
  }
);
