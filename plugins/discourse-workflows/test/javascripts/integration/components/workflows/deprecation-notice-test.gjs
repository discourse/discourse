import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import DeprecationNotice from "discourse/plugins/discourse-workflows/admin/components/workflows/node/deprecation-notice";

const DEPRECATION = {
  changes: { editor: "actor", user: "author" },
  superseded_by: "2.0",
};

module(
  "Integration | Component | workflows deprecation notice",
  function (hooks) {
    setupRenderingTest(hooks);

    test("lists the output changes of the newer version", async function (assert) {
      await render(
        <template><DeprecationNotice @deprecation={{DEPRECATION}} /></template>
      );

      assert.dom(".workflows-deprecation-notice .alert").hasText(
        i18n("discourse_workflows.node_deprecated.notice", {
          changes: "editor → actor, user → author",
        })
      );
    });

    test("names the nodes that replace it", async function (assert) {
      const deprecation = {
        replaced_by: ["action:plugin_close", "action:topic"],
      };
      const nodeTypes = [
        {
          identifier: "action:plugin_close",
          name: "action:plugin_close",
          ui: { label_key: "discourse_workflows.nodes.action:post" },
        },
      ];

      await render(
        <template>
          <DeprecationNotice
            @deprecation={{deprecation}}
            @nodeTypes={{nodeTypes}}
          />
        </template>
      );

      assert.dom(".workflows-deprecation-notice .alert").hasText(
        i18n("discourse_workflows.node_deprecated.replaced_notice", {
          nodes: [
            i18n("discourse_workflows.nodes.action:post"),
            i18n("discourse_workflows.nodes.action:topic"),
          ].join(", "),
        })
      );
    });

    test("lists the output changes and the nodes taking over some operations", async function (assert) {
      const deprecation = {
        ...DEPRECATION,
        replaced_by: ["action:topic"],
      };

      await render(
        <template><DeprecationNotice @deprecation={{deprecation}} /></template>
      );

      assert.dom(".workflows-deprecation-notice .alert").hasText(
        [
          i18n("discourse_workflows.node_deprecated.notice", {
            changes: "editor → actor, user → author",
          }),
          i18n("discourse_workflows.node_deprecated.partly_replaced_notice", {
            nodes: i18n("discourse_workflows.nodes.action:topic"),
          }),
        ].join(" ")
      );
    });

    test("says a newer version exists when the output doesn't change", async function (assert) {
      const deprecation = {
        superseded_by: "2.0",
        replaced_by: ["action:topic"],
      };

      await render(
        <template><DeprecationNotice @deprecation={{deprecation}} /></template>
      );

      assert.dom(".workflows-deprecation-notice .alert").hasText(
        [
          i18n("discourse_workflows.node_deprecated.newer_version_notice"),
          i18n("discourse_workflows.node_deprecated.partly_replaced_notice", {
            nodes: i18n("discourse_workflows.nodes.action:topic"),
          }),
        ].join(" ")
      );
    });

    test("appends the translated notice", async function (assert) {
      const deprecation = {
        ...DEPRECATION,
        notice_key: "discourse_workflows.node_deprecated.topic_v1",
      };

      await render(
        <template><DeprecationNotice @deprecation={{deprecation}} /></template>
      );

      assert
        .dom(".workflows-deprecation-notice .alert")
        .includesText(i18n("discourse_workflows.node_deprecated.topic_v1"));
    });

    test("upgrades the node", async function (assert) {
      const upgrade = () => assert.step("upgrade");

      await render(
        <template>
          <DeprecationNotice
            @deprecation={{DEPRECATION}}
            @onUpgrade={{upgrade}}
          />
        </template>
      );
      await click(".workflows-deprecation-notice__upgrade");

      assert.verifySteps(["upgrade"]);
    });

    test("renders nothing for current versions", async function (assert) {
      await render(<template><DeprecationNotice /></template>);

      assert.dom(".workflows-deprecation-notice").doesNotExist();
    });
  }
);
