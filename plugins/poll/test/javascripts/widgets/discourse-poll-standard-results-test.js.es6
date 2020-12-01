import {
  moduleForWidget,
  widgetTest,
} from "discourse/tests/helpers/widget-test";
import EmberObject from "@ember/object";
import { queryAll } from "discourse/tests/helpers/qunit-helpers";

moduleForWidget("discourse-poll-standard-results");

const template = `{{mount-widget
                    widget="discourse-poll-standard-results"
                    args=(hash poll=poll isMultiple=isMultiple)}}`;

widgetTest("options in descending order", {
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
    assert.equal(queryAll(".option .percentage")[0].innerText, "56%");
    assert.equal(queryAll(".option .percentage")[1].innerText, "44%");
  },
});

widgetTest("options in ascending order", {
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
    assert.equal(queryAll(".option .percentage")[0].innerText, "56%");
    assert.equal(queryAll(".option .percentage")[1].innerText, "44%");
  },
});

widgetTest("multiple options in descending order", {
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
    assert.equal(percentages[0].innerText, "41%");
    assert.equal(percentages[1].innerText, "33%");
    assert.equal(percentages[2].innerText, "16%");
    assert.equal(percentages[3].innerText, "8%");

    assert.equal(
      queryAll(".option")[3].querySelectorAll("span")[1].innerText,
      "a"
    );
    assert.equal(percentages[4].innerText, "8%");
    assert.equal(
      queryAll(".option")[4].querySelectorAll("span")[1].innerText,
      "b"
    );
  },
});
