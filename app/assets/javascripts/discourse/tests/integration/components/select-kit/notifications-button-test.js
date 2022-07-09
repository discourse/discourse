import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import selectKit, {
  setDefaultState,
} from "discourse/tests/helpers/select-kit-helper";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule(
  "Integration | Component | select-kit/notifications-button",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
    });

    componentTest("default", {
      template: hbs`
      {{notifications-button
        value=value
        options=(hash
          i18nPrefix=i18nPrefix
          i18nPostfix=i18nPostfix
        )
      }}
    `,

      beforeEach() {
        this.set("value", 1);

        setDefaultState(this, 1, { i18nPrefix: "pre", i18nPostfix: "post" });
      },

      async test(assert) {
        assert.ok(this.subject.header().value());

        assert.ok(
          this.subject
            .header()
            .label()
            .includes(`${this.i18nPrefix}.regular${this.i18nPostfix}`),
          "it shows the regular choice when value is not set"
        );

        const icon = this.subject.header().icon();
        assert.ok(
          icon.classList.contains("d-icon-d-regular"),
          "it shows the correct icon"
        );
      },
    });
  }
);
