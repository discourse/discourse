import { click, fillIn, find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ComposerEditor from "discourse/components/composer-editor";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";

module("Integration | Component | ComposerEditor", function (hooks) {
  setupRenderingTest(hooks);

  test("warns about users that will not see a mention", async function (assert) {
    const expectation = (warning) => {
      if (warning.name === "user-no") {
        assert.deepEqual(warning, { name: "user-no", reason: "a reason" });
      } else if (warning.name === "user-nope") {
        assert.deepEqual(warning, { name: "user-nope", reason: "a reason" });
      }
    };

    pretender.get("/composer/mentions", () => {
      return response({
        users: ["user-ok", "user-no", "user-nope"],
        user_reasons: {
          "user-no": "a reason",
          "user-nope": "a reason",
        },
        groups: {},
        group_reasons: {},
        max_users_notified_per_group_mention: 100,
      });
    });

    const originalComposerService = this.owner.lookup("service:composer");
    const composerMockClass = class ComposerMock extends originalComposerService.constructor {
      cannotSeeMention() {
        expectation(...arguments);
      }
    };
    this.owner.unregister("service:composer");
    this.owner.register("service:composer", new composerMockClass(this.owner), {
      instantiate: false,
    });

    await render(<template><ComposerEditor /></template>);

    await fillIn("textarea", "@user-no @user-ok @user-nope");
  });

  test("preview sanitizes HTML", async function (assert) {
    await render(<template><ComposerEditor /></template>);

    await fillIn(".d-editor-input", `"><svg onload="prompt(/xss/)"></svg>`);
    assert.dom(".d-editor-preview").hasHtml('<p>"&gt;<svg></svg></p>');
  });

  test("placeholder text changes when toggling rich editor", async function (assert) {
    await render(<template><ComposerEditor /></template>);

    const markdownPlaceholder = find(".d-editor-input").placeholder;

    assert.strictEqual(
      markdownPlaceholder,
      i18n("composer.reply_placeholder"),
      "Markdown editor placeholder text is correct"
    );

    await click(".composer-toggle-switch");

    const richPlaceholder = find(".d-editor-input [data-placeholder]").dataset
      .placeholder;

    assert.strictEqual(
      richPlaceholder,
      i18n("composer.reply_placeholder_rte"),
      "Rich editor placeholder text is correct"
    );
  });
});
