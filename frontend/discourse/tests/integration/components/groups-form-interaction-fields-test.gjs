import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import GroupsFormInteractionFields from "discourse/components/groups-form-interaction-fields";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

module(
  "Integration | Component | GroupsFormInteractionFields",
  function (hooks) {
    setupRenderingTest(hooks);

    test("shows and updates the alias levels", async function (assert) {
      const model = { mentionable_level: 0, messageable_level: 99 };

      await render(
        <template><GroupsFormInteractionFields @model={{model}} /></template>
      );

      const mentionable = selectKit(".groups-form-mentionable-level");
      assert.strictEqual(mentionable.header().value(), "0");
      assert.strictEqual(
        mentionable.header().label(),
        i18n("groups.alias_levels.nobody"),
        "shows the lowest level"
      );

      await mentionable.expand();
      await mentionable.selectRowByValue(3);

      assert.strictEqual(model.mentionable_level, 3, "writes the picked level");
      assert.strictEqual(
        mentionable.header().value(),
        "3",
        "shows the picked level"
      );
      assert.strictEqual(
        selectKit(".groups-form-messageable-level").header().value(),
        "99"
      );
    });
  }
);
