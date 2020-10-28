import { queryAll } from "discourse/tests/helpers/qunit-helpers";
import {
  moduleForWidget,
  widgetTest,
} from "discourse/tests/helpers/widget-test";

moduleForWidget("small-user-list");

widgetTest("renders avatars and support for unknown", {
  template: '{{mount-widget widget="small-user-list" args=args}}',
  beforeEach() {
    this.set("args", {
      users: [
        { id: 456, username: "eviltrout" },
        { id: 457, username: "someone", unknown: true },
      ],
    });
  },
  async test(assert) {
    assert.ok(queryAll("[data-user-card=eviltrout]").length === 1);
    assert.ok(queryAll("[data-user-card=someone]").length === 0);
    assert.ok(queryAll(".unknown").length, "includes unkown user");
  },
});
