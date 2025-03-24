import { hash } from "@ember/helper";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit, {
  setDefaultState,
} from "discourse/tests/helpers/select-kit-helper";
import NotificationsButton from "select-kit/components/notifications-button";

module(
  "Integration | Component | select-kit/notifications-button",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
    });

    test("default", async function (assert) {
      const self = this;

      this.set("value", 1);
      setDefaultState(this, 1, { i18nPrefix: "pre", i18nPostfix: "post" });

      await render(
        <template>
          <NotificationsButton
            @value={{self.value}}
            @options={{hash
              i18nPrefix=self.i18nPrefix
              i18nPostfix=self.i18nPostfix
            }}
          />
        </template>
      );

      assert.true(!!this.subject.header().value());

      assert.true(
        this.subject
          .header()
          .label()
          .includes(`${this.i18nPrefix}.regular${this.i18nPostfix}`),
        "shows the regular choice when value is not set"
      );

      assert
        .dom(this.subject.header().icon())
        .hasClass("d-icon-d-regular", "shows the correct icon");
    });
  }
);
