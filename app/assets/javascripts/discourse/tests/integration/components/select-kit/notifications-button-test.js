import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit, {
  setDefaultState,
} from "discourse/tests/helpers/select-kit-helper";

module(
  "Integration | Component | select-kit/notifications-button",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
    });

    test("default", async function (assert) {
      this.set("value", 1);
      setDefaultState(this, 1, { i18nPrefix: "pre", i18nPostfix: "post" });

      await render(hbs`
        <NotificationsButton
          @value={{this.value}}
          @options={{hash
            i18nPrefix=this.i18nPrefix
            i18nPostfix=this.i18nPostfix
          }}
        />
      `);

      assert.ok(this.subject.header().value());

      assert.ok(
        this.subject
          .header()
          .label()
          .includes(`${this.i18nPrefix}.regular${this.i18nPostfix}`),
        "it shows the regular choice when value is not set"
      );

      assert
        .dom(this.subject.header().icon())
        .hasClass("d-icon-d-regular", "shows the correct icon");
    });
  }
);
