import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import MountWidget from "discourse/components/mount-widget";
import { withSilencedDeprecations } from "discourse/lib/deprecated";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import I18n from "discourse-i18n";

// TODO (glimmer-post-stream) remove this test when removing the widget post stream code
module(
  "Integration | Component | Widget | post-small-action",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.glimmer_post_stream_mode = "disabled";
    });

    test("does not have delete/edit/recover buttons by default", async function (assert) {
      const self = this;

      this.set("args", { id: 123 });

      await render(
        <template>
          <MountWidget @widget="post-small-action" @args={{self.args}} />
        </template>
      );

      assert.dom(".small-action-desc .small-action-delete").doesNotExist();
      assert.dom(".small-action-desc .small-action-recover").doesNotExist();
      assert.dom(".small-action-desc .small-action-edit").doesNotExist();
    });

    test("shows edit button if canEdit", async function (assert) {
      const self = this;

      this.set("args", { id: 123, canEdit: true });

      await render(
        <template>
          <MountWidget @widget="post-small-action" @args={{self.args}} />
        </template>
      );

      assert
        .dom(".small-action-desc .small-action-edit")
        .exists("adds the edit small action button");
    });

    test("uses custom widget if actionDescriptionWidget", async function (assert) {
      const self = this;

      this.set("args", { id: 123, actionDescriptionWidget: "button" });

      await render(
        <template>
          <MountWidget @widget="post-small-action" @args={{self.args}} />
        </template>
      );

      assert
        .dom(".small-action .widget-button")
        .exists("adds the custom widget");
    });

    test("does not show edit button if canRecover even if canEdit", async function (assert) {
      const self = this;

      this.set("args", { id: 123, canEdit: true, canRecover: true });

      await render(
        <template>
          <MountWidget @widget="post-small-action" @args={{self.args}} />
        </template>
      );

      assert
        .dom(".small-action-desc .small-action-edit")
        .doesNotExist("does not add the edit small action button");
      assert
        .dom(".small-action-desc .small-action-recover")
        .exists("adds the recover small action button");
    });

    test("shows delete button if canDelete", async function (assert) {
      const self = this;

      this.set("args", { id: 123, canDelete: true });

      await render(
        <template>
          <MountWidget @widget="post-small-action" @args={{self.args}} />
        </template>
      );

      assert
        .dom(".small-action-desc .small-action-delete")
        .exists("adds the delete small action button");
    });

    test("shows undo button if canRecover", async function (assert) {
      const self = this;

      this.set("args", { id: 123, canRecover: true });

      await render(
        <template>
          <MountWidget @widget="post-small-action" @args={{self.args}} />
        </template>
      );

      assert
        .dom(".small-action-desc .small-action-recover")
        .exists("adds the recover small action button");
    });

    test("`addGroupPostSmallActionCode` plugin api", async function (assert) {
      const self = this;

      withPluginApi("1.6.0", (api) => {
        api.addGroupPostSmallActionCode("some_code");
      });

      this.set("args", {
        id: 123,
        actionCode: "some_code",
        actionCodeWho: "somegroup",
      });

      I18n.translations[I18n.locale].js.action_codes = {
        some_code: "Some %{who} Code Action",
      };
      await render(
        <template>
          <MountWidget @widget="post-small-action" @args={{self.args}} />
        </template>
      );
      assert
        .dom(".small-action")
        .hasText(
          "Some @somegroup Code Action",
          "the action code text was rendered correctly"
        );
      assert
        .dom("a.mention-group")
        .hasAttribute(
          "href",
          "/g/somegroup",
          "the group mention link has the correct href"
        );
    });

    test("`addPostSmallActionClassesCallback` plugin api", async function (assert) {
      const self = this;

      withSilencedDeprecations("discourse.post-stream-widget-overrides", () => {
        withPluginApi("1.6.0", (api) => {
          api.addPostSmallActionClassesCallback((postAttrs) => {
            if (postAttrs.canRecover) {
              return ["abcde"];
            }
          });
        });
      });

      this.set("args", { id: 123, canRecover: false });

      await render(
        <template>
          <MountWidget @widget="post-small-action" @args={{self.args}} />
        </template>
      );

      assert
        .dom(".abcde")
        .doesNotExist(
          "custom CSS class is not added when condition is not met"
        );

      this.set("args", { id: 123, canRecover: true });

      await render(
        <template>
          <MountWidget @widget="post-small-action" @args={{self.args}} />
        </template>
      );

      assert
        .dom(".abcde")
        .exists("adds custom CSS class as registered from the plugin API");
    });
  }
);
