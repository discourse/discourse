import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import selectKit from "discourse/tests/helpers/select-kit-helper";

discourseModule(
  "Integration | Component | select-kit/email-group-user-chooser",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
      this.setProperties({
        value: [],
        onChange() {},
      });
    });

    componentTest("autofocus option set to true", {
      template: hbs`{{email-group-user-chooser
        value=value
        onChange=onChange
        options=(hash
          autofocus=true
        )
      }}`,

      async test(assert) {
        this.subject;
        assert.ok(
          this.subject.header().el()[0].classList.contains("is-focused"),
          "select-kit header has is-focused class"
        );
        assert.ok(
          this.subject.filter().el()[0].querySelector(".filter-input")
            .autofocus,
          "filter input has autofocus attribute"
        );
      },
    });

    componentTest("without autofocus", {
      template: hbs`{{email-group-user-chooser
        value=value
        onChange=onChange
      }}`,

      async test(assert) {
        this.subject;
        assert.ok(
          !this.subject.header().el()[0].classList.contains("is-focused"),
          "select-kit header doesn't have is-focused class"
        );
        assert.ok(
          !this.subject.filter().el()[0].querySelector(".filter-input")
            .autofocus,
          "filter input doesn't have autofocus attribute"
        );
      },
    });
  }
);
