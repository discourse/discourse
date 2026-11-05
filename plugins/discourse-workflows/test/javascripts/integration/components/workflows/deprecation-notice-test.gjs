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
