import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import EmberObject from "@ember/object";
import {
  discourseModule,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule(
  "Integration | Component | Widget | discourse-poll-standard-results",
  function (hooks) {
    setupRenderingTest(hooks);

    const template = hbs`{{mount-widget
                    widget="discourse-poll-standard-results"
                    args=(hash poll=poll isMultiple=isMultiple)}}`;

    componentTest("options in descending order", {
      template,

      beforeEach() {
        this.set(
          "poll",
          EmberObject.create({
            options: [{ votes: 5 }, { votes: 4 }],
            voters: 9,
          })
        );
      },

      test(assert) {
        assert.strictEqual(queryAll(".option .percentage")[0].innerText, "56%");
        assert.strictEqual(queryAll(".option .percentage")[1].innerText, "44%");
      },
    });

    componentTest("options in ascending order", {
      template,

      beforeEach() {
        this.set(
          "poll",
          EmberObject.create({
            options: [{ votes: 4 }, { votes: 5 }],
            voters: 9,
          })
        );
      },

      test(assert) {
        assert.strictEqual(queryAll(".option .percentage")[0].innerText, "56%");
        assert.strictEqual(queryAll(".option .percentage")[1].innerText, "44%");
      },
    });

    componentTest("multiple options in descending order", {
      template,

      beforeEach() {
        this.set("isMultiple", true);
        this.set(
          "poll",
          EmberObject.create({
            type: "multiple",
            options: [
              { votes: 5, html: "a" },
              { votes: 2, html: "b" },
              { votes: 4, html: "c" },
              { votes: 1, html: "b" },
              { votes: 1, html: "a" },
            ],
            voters: 12,
          })
        );
      },

      test(assert) {
        let percentages = queryAll(".option .percentage");
        assert.strictEqual(percentages[0].innerText, "41%");
        assert.strictEqual(percentages[1].innerText, "33%");
        assert.strictEqual(percentages[2].innerText, "16%");
        assert.strictEqual(percentages[3].innerText, "8%");

        assert.strictEqual(
          queryAll(".option")[3].querySelectorAll("span")[1].innerText,
          "a"
        );
        assert.strictEqual(percentages[4].innerText, "8%");
        assert.strictEqual(
          queryAll(".option")[4].querySelectorAll("span")[1].innerText,
          "b"
        );
      },
    });
  }
);
