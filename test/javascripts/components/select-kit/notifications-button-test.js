import componentTest from "helpers/component-test";
import { testSelectKitModule, setDefaultState } from "./select-kit-test-helper";

testSelectKitModule("notifications-button");

componentTest("default", {
  template: `
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

    const icon = this.subject.header().icon()[0];
    assert.ok(
      icon.classList.contains("d-icon-d-regular"),
      "it shows the correct icon"
    );
  }
});
