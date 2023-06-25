import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import selectKit from "discourse/tests/helpers/select-kit-helper";

function setTime(time) {
  this.setProperties(time);
}

module("Integration | Component | time-input", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.set("subject", selectKit());
  });

  test("default", async function (assert) {
    this.setProperties({ hours: "14", minutes: "58" });

    await render(
      hbs`<TimeInput @hours={{this.hours}} @minutes={{this.minutes}} />`
    );

    assert.strictEqual(this.subject.header().name(), "14:58");
  });

  test("prevents mutations", async function (assert) {
    this.setProperties({ hours: "14", minutes: "58" });

    await render(
      hbs`<TimeInput @hours={{this.hours}} @minutes={{this.minutes}} />`
    );

    await this.subject.expand();
    await this.subject.selectRowByIndex(3);
    assert.strictEqual(this.subject.header().name(), "14:58");
  });

  test("allows mutations through actions", async function (assert) {
    this.setProperties({ hours: "14", minutes: "58" });
    this.set("onChange", setTime);

    await render(
      hbs`<TimeInput @hours={{this.hours}} @minutes={{this.minutes}} @onChange={{this.onChange}} />`
    );

    await this.subject.expand();
    await this.subject.selectRowByIndex(3);
    assert.strictEqual(this.subject.header().name(), "00:45");
  });

  test("dropdown values", async function (assert) {
    this.setProperties({
      hours: "22",
      minutes: "19",
      relativeDate: moment("2032-01-01 20:40")
    });
    this.set("onChange", setTime);

    await render(
      hbs`<TimeInput @hours={{this.hours}} @minutes={{this.minutes}} @relativeDate={{this.relativeDate}}/>`
    );

    await this.subject.expand();
    const rows = this.subject.rows();
    assert.deepEqual(
      Array.from(rows).map((r) => {
        return parseInt(r.dataset.value);
      }),
      [1240,1255,1270,1285,1300,1330,1339,1360,1390,1420]
    );
  });
});
