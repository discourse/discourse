import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
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
          primary_group_flair_url: "fa-bars",
          primary_group_flair_bg_color: "CC0000",
          primary_group_flair_color: "FFFFFF",
        });
      },
      test(assert) {
        assert.ok(queryAll(".avatar-flair").length, "it has the tag");
        assert.ok(queryAll("svg.d-icon-bars").length, "it has the svg icon");
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
          primary_group_flair_url: "/images/avatar.png",
        });
      },
      test(assert) {
        assert.ok(queryAll(".avatar-flair").length, "it has the tag");
        assert.ok(queryAll("svg").length === 0, "it does not have an svg icon");
      },
    });
  }
);
