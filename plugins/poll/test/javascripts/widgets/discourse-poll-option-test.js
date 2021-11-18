import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule(
  "Integration | Component | Widget | discourse-poll-option",
  function (hooks) {
    setupRenderingTest(hooks);
    const template = hbs`{{mount-widget
                    widget="discourse-poll-option"
                    args=(hash option=option isMultiple=isMultiple vote=vote)}}`;

    componentTest("single, not selected", {
      template,

      beforeEach() {
        this.set("option", { id: "opt-id" });
        this.set("vote", []);
      },

      test(assert) {
        assert.ok(
          queryAll("li .d-icon-far-circle:nth-of-type(1)").length === 1
        );
      },
    });

    componentTest("single, selected", {
      template,

      beforeEach() {
        this.set("option", { id: "opt-id" });
        this.set("vote", ["opt-id"]);
      },

      test(assert) {
        assert.ok(queryAll("li .d-icon-circle:nth-of-type(1)").length === 1);
      },
    });

    componentTest("multi, not selected", {
      template,

      beforeEach() {
        this.setProperties({
          option: { id: "opt-id" },
          isMultiple: true,
          vote: [],
        });
      },

      test(assert) {
        assert.ok(
          queryAll("li .d-icon-far-square:nth-of-type(1)").length === 1
        );
      },
    });

    componentTest("multi, selected", {
      template,

      beforeEach() {
        this.setProperties({
          option: { id: "opt-id" },
          isMultiple: true,
          vote: ["opt-id"],
        });
      },

      test(assert) {
        assert.ok(
          queryAll("li .d-icon-far-check-square:nth-of-type(1)").length === 1
        );
      },
    });
  }
);
