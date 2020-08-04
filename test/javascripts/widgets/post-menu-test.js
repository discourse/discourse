import { moduleForWidget, widgetTest } from "helpers/widget-test";
import { withPluginApi } from "discourse/lib/plugin-api";

moduleForWidget("post-menu");

widgetTest("add extra button", {
  template: '{{mount-widget widget="post-menu" args=args}}',
  beforeEach() {
    this.set("args", {});
    withPluginApi("0.8", api => {
      api.addPostMenuButton("coffee", () => {
        return {
          action: "drinkCoffee",
          icon: "coffee",
          className: "hot-coffee",
          title: "coffee.title",
          position: "first"
        };
      });
    });
  },
  async test(assert) {
    assert.ok(
      find(".actions .extra-buttons .hot-coffee").length === 1,
      "It renders extra button"
    );
  }
});

widgetTest("remove extra button", {
  template: '{{mount-widget widget="post-menu" args=args}}',
  beforeEach() {
    this.set("args", {});
    withPluginApi("0.8", api => {
      api.removePostMenuButton("coffee");
    });
  },
  async test(assert) {
    assert.ok(
      find(".actions .extra-buttons .hot-coffee").length === 0,
      "It doesn't removes coffee button"
    );
  }
});
