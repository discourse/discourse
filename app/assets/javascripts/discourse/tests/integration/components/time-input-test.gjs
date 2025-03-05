import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import TimeInput from "discourse/components/time-input";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
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
    const self = this;

    this.setProperties({ hours: "14", minutes: "58" });

    await render(
      <template>
        <TimeInput @hours={{self.hours}} @minutes={{self.minutes}} />
      </template>
    );

    assert.strictEqual(this.subject.header().name(), "14:58");
  });

  test("prevents mutations", async function (assert) {
    const self = this;

    this.setProperties({ hours: "14", minutes: "58" });

    await render(
      <template>
        <TimeInput @hours={{self.hours}} @minutes={{self.minutes}} />
      </template>
    );

    await this.subject.expand();
    await this.subject.selectRowByIndex(3);
    assert.strictEqual(this.subject.header().name(), "14:58");
  });

  test("allows mutations through actions", async function (assert) {
    const self = this;

    this.setProperties({ hours: "14", minutes: "58" });
    this.set("onChange", setTime);

    await render(
      <template>
        <TimeInput
          @hours={{self.hours}}
          @minutes={{self.minutes}}
          @onChange={{self.onChange}}
        />
      </template>
    );

    await this.subject.expand();
    await this.subject.selectRowByIndex(3);
    assert.strictEqual(this.subject.header().name(), "00:45");
  });
});
