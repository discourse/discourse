import { moduleForWidget, widgetTest } from "helpers/widget-test";

moduleForWidget("actions-summary");

widgetTest("post deleted", {
  template: '{{mount-widget widget="actions-summary" args=args}}',
  beforeEach() {
    this.set("args", {
      deleted_at: "2016-01-01",
      deletedByUsername: "eviltrout",
      deletedByAvatarTemplate: "/images/avatar.png"
    });
  },
  test(assert) {
    assert.ok(
      find(".post-action .d-icon-far-trash-alt").length === 1,
      "it has the deleted icon"
    );
    assert.ok(
      find(".avatar[title=eviltrout]").length === 1,
      "it has the deleted by avatar"
    );
  }
});
