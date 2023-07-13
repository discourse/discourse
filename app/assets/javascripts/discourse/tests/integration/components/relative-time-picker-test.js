import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module("Integration | Component | relative-time-picker", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.set("subject", selectKit());
  });

  test("prefills and preselects minutes", async function (assert) {
    await render(hbs`<RelativeTimePicker @durationMinutes="5" />`);

    const prefilledDuration = query(".relative-time-duration").value;
    assert.strictEqual(this.subject.header().value(), "mins");
    assert.strictEqual(prefilledDuration, "5");
  });

  test("prefills and preselects null minutes", async function (assert) {
    await render(hbs`<RelativeTimePicker @durationMinutes={{null}} />`);

    const prefilledDuration = query(".relative-time-duration").value;
    assert.strictEqual(this.subject.header().value(), "mins");
    assert.strictEqual(prefilledDuration, "");
  });

  test("prefills and preselects hours based on translated minutes", async function (assert) {
    await render(hbs`<RelativeTimePicker @durationMinutes="90" />`);

    const prefilledDuration = query(".relative-time-duration").value;
    assert.strictEqual(this.subject.header().value(), "hours");
    assert.strictEqual(prefilledDuration, "1.5");
  });

  test("prefills and preselects days based on translated minutes", async function (assert) {
    await render(hbs`<RelativeTimePicker @durationMinutes="2880" />`);

    const prefilledDuration = query(".relative-time-duration").value;
    assert.strictEqual(this.subject.header().value(), "days");
    assert.strictEqual(prefilledDuration, "2");
  });

  test("prefills and preselects months based on translated minutes", async function (assert) {
    await render(hbs`<RelativeTimePicker @durationMinutes="129600" />`);

    const prefilledDuration = query(".relative-time-duration").value;
    assert.strictEqual(this.subject.header().value(), "months");
    assert.strictEqual(prefilledDuration, "3");
  });

  test("prefills and preselects years based on translated minutes", async function (assert) {
    await render(hbs`<RelativeTimePicker @durationMinutes="525600" />`);

    const prefilledDuration = query(".relative-time-duration").value;
    assert.strictEqual(this.subject.header().value(), "years");
    assert.strictEqual(prefilledDuration, "1");
  });

  test("prefills and preselects hours", async function (assert) {
    await render(hbs`<RelativeTimePicker @durationHours="5" />`);

    const prefilledDuration = query(".relative-time-duration").value;
    assert.strictEqual(this.subject.header().value(), "hours");
    assert.strictEqual(prefilledDuration, "5");
  });

  test("prefills and preselects null hours", async function (assert) {
    await render(hbs`<RelativeTimePicker @durationHours={{null}} />`);

    const prefilledDuration = query(".relative-time-duration").value;
    assert.strictEqual(this.subject.header().value(), "hours");
    assert.strictEqual(prefilledDuration, "");
  });

  test("prefills and preselects minutes based on translated hours", async function (assert) {
    await render(hbs`<RelativeTimePicker @durationHours="0.5" />`);

    const prefilledDuration = query(".relative-time-duration").value;
    assert.strictEqual(this.subject.header().value(), "mins");
    assert.strictEqual(prefilledDuration, "30");
  });

  test("prefills and preselects days based on translated hours", async function (assert) {
    await render(hbs`<RelativeTimePicker @durationHours="48" />`);

    const prefilledDuration = query(".relative-time-duration").value;
    assert.strictEqual(this.subject.header().value(), "days");
    assert.strictEqual(prefilledDuration, "2");
  });

  test("prefills and preselects months based on translated hours", async function (assert) {
    await render(hbs`<RelativeTimePicker @durationHours="2160" />`);

    const prefilledDuration = query(".relative-time-duration").value;
    assert.strictEqual(this.subject.header().value(), "months");
    assert.strictEqual(prefilledDuration, "3");
  });

  test("prefills and preselects years based on translated hours", async function (assert) {
    await render(hbs`<RelativeTimePicker @durationHours="17520" />`);

    const prefilledDuration = query(".relative-time-duration").value;
    assert.strictEqual(this.subject.header().value(), "years");
    assert.strictEqual(prefilledDuration, "2");
  });
});
