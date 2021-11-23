import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  count,
  discourseModule,
  exists,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { resetPostMenuExtraButtons } from "discourse/widgets/post-menu";
import { withPluginApi } from "discourse/lib/plugin-api";

discourseModule(
  "Integration | Component | Widget | post-menu",
  function (hooks) {
    hooks.afterEach(() => {
      resetPostMenuExtraButtons();
    });

    setupRenderingTest(hooks);

    componentTest("add extra button", {
      template: hbs`{{mount-widget widget="post-menu" args=args}}`,
      beforeEach() {
        this.set("args", {});
        withPluginApi("0.14.0", (api) => {
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
        assert.strictEqual(
          count(".actions .extra-buttons .hot-coffee"),
          1,
          "It renders extra button"
        );
      },
    });

    componentTest("removes button based on callback", {
      template: hbs`{{mount-widget widget="post-menu" args=args}}`,

      beforeEach() {
        this.set("args", { canCreatePost: true, canRemoveReply: true });

        withPluginApi("0.14.0", (api) => {
          api.removePostMenuButton("reply", (attrs) => {
            return attrs.canRemoveReply;
          });
        });
      },

      async test(assert) {
        assert.ok(!exists(".actions .reply"), "it removes reply button");
      },
    });

    componentTest("does not remove butto", {
      template: hbs`{{mount-widget widget="post-menu" args=args}}`,

      beforeEach() {
        this.set("args", { canCreatePost: true, canRemoveReply: false });

        withPluginApi("0.14.0", (api) => {
          api.removePostMenuButton("reply", (attrs) => {
            return attrs.canRemoveReply;
          });
        });
      },

      async test(assert) {
        assert.ok(exists(".actions .reply"), "it does not remove reply button");
      },
    });

    componentTest("removes button", {
      template: hbs`{{mount-widget widget="post-menu" args=args}}`,
      beforeEach() {
        this.set("args", { canCreatePost: true });

        withPluginApi("0.14.0", (api) => {
          api.removePostMenuButton("reply");
        });
      },

      async test(assert) {
        assert.ok(!exists(".actions .reply"), "it removes reply button");
      },
    });
  }
);
