import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  count,
  discourseModule,
  exists,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { withPluginApi } from "discourse/lib/plugin-api";

discourseModule(
  "Integration | Component | Widget | post-menu",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("add extra button", {
      template: hbs`{{mount-widget widget="post-menu" args=args}}`,
      beforeEach() {
        this.set("args", {});
        withPluginApi("0.8", (api) => {
          api.addPostMenuButton("coffee", () => {
            return {
              action: "drinkCoffee",
              icon: "coffee",
              className: "hot-coffee",
              title: "coffee.title",
              position: "first",
            };
          });
        });
      },
      async test(assert) {
        assert.equal(
          count(".actions .extra-buttons .hot-coffee"),
          1,
          "It renders extra button"
        );
      },
    });

    componentTest("remove extra button", {
      template: hbs`{{mount-widget widget="post-menu" args=args}}`,
      beforeEach() {
        this.set("args", {});
        withPluginApi("0.8", (api) => {
          api.removePostMenuButton("coffee");
        });
      },
      async test(assert) {
        assert.ok(
          !exists(".actions .extra-buttons .hot-coffee"),
          "It doesn't removes coffee button"
        );
      },
    });
  }
);
