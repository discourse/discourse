import { moduleForWidget, widgetTest } from "helpers/widget-test";

moduleForWidget("button");

widgetTest("icon only button", {
  template: '{{mount-widget widget="button" args=args}}',

  beforeEach() {
    this.set("args", { icon: "smile-o" });
  },

  test(assert) {
    assert.ok(
      this.$("button.btn.btn-icon.no-text").length,
      "it has all the classes"
    );
    assert.ok(
      this.$("button .d-icon.d-icon-smile-o").length,
      "it has the icon"
    );
  }
});

widgetTest("icon and text button", {
  template: '{{mount-widget widget="button" args=args}}',

  beforeEach() {
    this.set("args", { icon: "plus", label: "topic.create" });
  },

  test(assert) {
    assert.ok(
      this.$("button.btn.btn-icon-text").length,
      "it has all the classes"
    );
    assert.ok(this.$("button .d-icon.d-icon-plus").length, "it has the icon");
    assert.ok(this.$("button span.d-button-label").length, "it has the label");
  }
});

widgetTest("text only button", {
  template: '{{mount-widget widget="button" args=args}}',

  beforeEach() {
    this.set("args", { label: "topic.create" });
  },

  test(assert) {
    assert.ok(this.$("button.btn.btn-text").length, "it has all the classes");
    assert.ok(this.$("button span.d-button-label").length, "it has the label");
  }
});
