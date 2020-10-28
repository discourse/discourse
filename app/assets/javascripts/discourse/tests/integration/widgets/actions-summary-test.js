import { queryAll } from "discourse/tests/helpers/qunit-helpers";
import {
  moduleForWidget,
  widgetTest,
} from "discourse/tests/helpers/widget-test";

moduleForWidget("actions-summary");

widgetTest("post deleted", {
  template: '{{mount-widget widget="actions-summary" args=args}}',
  beforeEach() {
    this.set("args", {
      deleted_at: "2016-01-01",
      deletedByUsername: "eviltrout",
      deletedByAvatarTemplate: "/images/avatar.png",
    });
  },
  test(assert) {
    assert.ok(
      queryAll(".post-action .d-icon-far-trash-alt").length === 1,
      "it has the deleted icon"
    );
    assert.ok(
      queryAll(".avatar[title=eviltrout]").length === 1,
      "it has the deleted by avatar"
    );
  },
});
