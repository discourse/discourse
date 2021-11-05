import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule, query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import selectKit from "discourse/tests/helpers/select-kit-helper";

discourseModule(
  "Integration | Component | relative-time-picker",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
    });

    componentTest("prefills and preselects minutes", {
      template: hbs`{{relative-time-picker durationMinutes="5"}}`,

      test(assert) {
        const prefilledDuration = query(".relative-time-duration").value;
        assert.strictEqual(this.subject.header().value(), "mins");
        assert.strictEqual(prefilledDuration, "5");
      },
    });

    componentTest("prefills and preselects hours based on translated minutes", {
      template: hbs`{{relative-time-picker durationMinutes="90"}}`,

      test(assert) {
        const prefilledDuration = query(".relative-time-duration").value;
        assert.strictEqual(this.subject.header().value(), "hours");
        assert.strictEqual(prefilledDuration, "1.5");
      },
    });

    componentTest("prefills and preselects days based on translated minutes", {
      template: hbs`{{relative-time-picker durationMinutes="2880"}}`,

      test(assert) {
        const prefilledDuration = query(".relative-time-duration").value;
        assert.strictEqual(this.subject.header().value(), "days");
        assert.strictEqual(prefilledDuration, "2");
      },
    });

    componentTest(
      "prefills and preselects months based on translated minutes",
      {
        template: hbs`{{relative-time-picker durationMinutes="129600"}}`,

        test(assert) {
          const prefilledDuration = query(".relative-time-duration").value;
          assert.strictEqual(this.subject.header().value(), "months");
          assert.strictEqual(prefilledDuration, "3");
        },
      }
    );

    componentTest("prefills and preselects years based on translated minutes", {
      template: hbs`{{relative-time-picker durationMinutes="525600"}}`,

      test(assert) {
        const prefilledDuration = query(".relative-time-duration").value;
        assert.strictEqual(this.subject.header().value(), "years");
        assert.strictEqual(prefilledDuration, "1");
      },
    });

    componentTest("prefills and preselects hours", {
      template: hbs`{{relative-time-picker durationHours="5"}}`,

      test(assert) {
        const prefilledDuration = query(".relative-time-duration").value;
        assert.strictEqual(this.subject.header().value(), "hours");
        assert.strictEqual(prefilledDuration, "5");
      },
    });

    componentTest("prefills and preselects minutes based on translated hours", {
      template: hbs`{{relative-time-picker durationHours="0.5"}}`,

      test(assert) {
        const prefilledDuration = query(".relative-time-duration").value;
        assert.strictEqual(this.subject.header().value(), "mins");
        assert.strictEqual(prefilledDuration, "30");
      },
    });

    componentTest("prefills and preselects days based on translated hours", {
      template: hbs`{{relative-time-picker durationHours="48"}}`,

      test(assert) {
        const prefilledDuration = query(".relative-time-duration").value;
        assert.strictEqual(this.subject.header().value(), "days");
        assert.strictEqual(prefilledDuration, "2");
      },
    });

    componentTest("prefills and preselects months based on translated hours", {
      template: hbs`{{relative-time-picker durationHours="2160"}}`,

      test(assert) {
        const prefilledDuration = query(".relative-time-duration").value;
        assert.strictEqual(this.subject.header().value(), "months");
        assert.strictEqual(prefilledDuration, "3");
      },
    });

    componentTest("prefills and preselects years based on translated hours", {
      template: hbs`{{relative-time-picker durationHours="17520"}}`,

      test(assert) {
        const prefilledDuration = query(".relative-time-duration").value;
        assert.strictEqual(this.subject.header().value(), "years");
        assert.strictEqual(prefilledDuration, "2");
      },
    });
  }
);
