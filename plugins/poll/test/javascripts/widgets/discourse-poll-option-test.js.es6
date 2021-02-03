import {
  moduleForWidget,
  widgetTest,
} from "discourse/tests/helpers/widget-test";
import { queryAll } from "discourse/tests/helpers/qunit-helpers";

moduleForWidget("discourse-poll-option");

const template = `{{mount-widget
                    widget="discourse-poll-option"
                    args=(hash option=option isMultiple=isMultiple vote=vote)}}`;

widgetTest("single, not selected", {
  template,

  beforeEach() {
    this.set("option", { id: "opt-id" });
    this.set("vote", []);
  },

  test(assert) {
    assert.ok(queryAll("li .d-icon-far-circle:nth-of-type(1)").length === 1);
  },
});

widgetTest("single, selected", {
  template,

  beforeEach() {
    this.set("option", { id: "opt-id" });
    this.set("vote", ["opt-id"]);
  },

  test(assert) {
    assert.ok(queryAll("li .d-icon-circle:nth-of-type(1)").length === 1);
  },
});

widgetTest("multi, not selected", {
  template,

  beforeEach() {
    this.setProperties({
      option: { id: "opt-id" },
      isMultiple: true,
      vote: [],
    });
  },

  test(assert) {
    assert.ok(queryAll("li .d-icon-far-square:nth-of-type(1)").length === 1);
  },
});

widgetTest("multi, selected", {
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
