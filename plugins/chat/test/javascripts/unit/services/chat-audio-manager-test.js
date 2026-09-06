import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { normalizeChatSoundName } from "discourse/plugins/chat/discourse/services/chat-audio-manager";

class MockAudioContext {
  state = "running";
  currentTime = 1;
  destination = {};
  oscillators = [];

  resume() {
    return Promise.resolve();
  }

  createOscillator() {
    const oscillator = {
      frequency: {
        value: null,
        setValueAtTime() {
          return undefined;
        },
        exponentialRampToValueAtTime() {
          return undefined;
        },
        linearRampToValueAtTime() {
          return undefined;
        },
      },
      connect: (node) => node,
      start() {
        return undefined;
      },
      stop() {
        return undefined;
      },
      type: null,
    };

    this.oscillators.push(oscillator);

    return oscillator;
  }

  createGain() {
    return {
      connect: (node) => node,
      gain: {
        setValueAtTime() {
          return undefined;
        },
        exponentialRampToValueAtTime() {
          return undefined;
        },
      },
    };
  }
}

module("Unit | Service | chat-audio-manager", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.originalAudioContext = window.AudioContext;
    this.context = new MockAudioContext();
    const context = this.context;

    window.AudioContext = class {
      constructor() {
        return context;
      }
    };

    this.subject = getOwner(this).lookup("service:chat-audio-manager");
  });

  hooks.afterEach(function () {
    this.context.state = "closed";
    window.AudioContext = this.originalAudioContext;
  });

  test("plays the incoming variant for the selected theme", async function (assert) {
    await this.subject.play("classic");

    assert.strictEqual(
      this.context.oscillators.length,
      2,
      "schedules the incoming sound sequence"
    );
  });

  test("plays the mention variant for the selected theme", async function (assert) {
    await this.subject.play("classic", { type: "mention" });

    assert.strictEqual(
      this.context.oscillators.length,
      3,
      "schedules the mention sound sequence"
    );
  });

  test("throttles notification sounds by default", async function (assert) {
    assert.true(await this.subject.play("classic"), "plays the first sound");
    assert.true(
      await this.subject.play("soft"),
      "reports a throttled drop as handled"
    );

    assert.strictEqual(
      this.context.oscillators.length,
      2,
      "skips the second sound while throttled"
    );
  });

  test("can bypass throttling for preference previews", async function (assert) {
    await this.subject.play("classic", { throttle: false });
    await this.subject.play("soft", { throttle: false });

    assert.strictEqual(
      this.context.oscillators.length,
      4,
      "plays each selected preview sound"
    );
  });

  test("skips the sound when the audio context stays suspended", async function (assert) {
    this.context.state = "suspended";

    assert.false(
      await this.subject.play("classic"),
      "reports the sound as unplayable"
    );
    assert.strictEqual(
      this.context.oscillators.length,
      0,
      "does not schedule a sound without user interaction"
    );
  });

  test("a failed attempt does not consume the throttle", async function (assert) {
    this.context.state = "suspended";

    assert.false(await this.subject.play("classic"), "first attempt fails");

    this.context.state = "running";

    assert.true(
      await this.subject.play("classic"),
      "the next alert can play immediately"
    );
    assert.strictEqual(
      this.context.oscillators.length,
      2,
      "schedules the sound"
    );
  });

  test("normalizes legacy sound names to the default theme", function (assert) {
    assert.strictEqual(
      normalizeChatSoundName("ding"),
      "classic",
      "uses the default theme for legacy sound names"
    );
  });
});
