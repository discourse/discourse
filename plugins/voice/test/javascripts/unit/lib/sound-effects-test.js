import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import {
  DEFAULT_SOUND_NAME,
  normalizeSoundName,
  playConnectedSound,
  playDeafenSound,
  playDisconnectedSound,
  playMuteSound,
  playUndeafenSound,
  playUnmuteSound,
  playUserJoinedSound,
  playUserLeftSound,
  resetSoundEffectsForTesting,
  startRingtone,
  startWaitingSound,
  stopCallSounds,
} from "discourse/plugins/voice/discourse/lib/voice/sound-effects";

const ROOM_CUES = [
  playConnectedSound,
  playDisconnectedSound,
  playUserJoinedSound,
  playUserLeftSound,
  playMuteSound,
  playUnmuteSound,
  playDeafenSound,
  playUndeafenSound,
];

class MockAudioParam {
  value = null;
  events = [];

  setValueAtTime(value, time) {
    this.events.push({ method: "set", value, time });
  }

  linearRampToValueAtTime(value, time) {
    this.events.push({ method: "linear", value, time });
  }

  exponentialRampToValueAtTime(value, time) {
    this.events.push({ method: "exponential", value, time });
  }
}

class MockAudioContext {
  state = "running";
  currentTime = 1;
  destination = {};
  oscillators = [];
  gains = [];

  resume() {
    return Promise.resolve();
  }

  createOscillator() {
    const oscillator = {
      type: "sine",
      frequency: new MockAudioParam(),
      connect: (node) => node,
      start(time) {
        this.startedAt = time;
      },
      stop(time) {
        this.stoppedAt = time;
      },
    };
    this.oscillators.push(oscillator);
    return oscillator;
  }

  createGain() {
    const gain = {
      disconnected: false,
      gain: new MockAudioParam(),
      connect: (node) => node,
      disconnect() {
        this.disconnected = true;
      },
    };
    this.gains.push(gain);
    return gain;
  }
}

module("Unit | Lib | sound-effects", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    resetSoundEffectsForTesting();
    this.originalAudioContext = window.AudioContext;
    this.context = new MockAudioContext();
    const context = this.context;

    window.AudioContext = class {
      constructor() {
        return context;
      }
    };
  });

  hooks.afterEach(function () {
    resetSoundEffectsForTesting();
    window.AudioContext = this.originalAudioContext;
  });

  test("normalizes sound names", function (assert) {
    for (const name of ["classic", "soft", "retro", "bubble", "ethereal"]) {
      assert.strictEqual(
        normalizeSoundName(name),
        name,
        `${name} is a supported sound theme`
      );
    }

    assert.strictEqual(
      normalizeSoundName(),
      DEFAULT_SOUND_NAME,
      "missing preferences use the default call sound"
    );
    assert.strictEqual(
      normalizeSoundName("ding"),
      DEFAULT_SOUND_NAME,
      "legacy preferences use the default call sound"
    );
  });

  test("applies every theme to all room cues", async function (assert) {
    for (const name of ["classic", "soft", "retro", "bubble", "ethereal"]) {
      this.context.oscillators = [];

      for (const playCue of ROOM_CUES) {
        await playCue(name);
      }

      assert.strictEqual(
        this.context.oscillators.length,
        12,
        `${name} schedules every room cue`
      );
      assert.strictEqual(
        this.context.oscillators.filter(({ type }) => type === "square").length,
        name === "retro" ? 12 : 0,
        `${name} uses the expected timbre`
      );
      assert.strictEqual(
        this.context.oscillators.filter(({ frequency }) =>
          frequency.events.some(({ method }) => method === "exponential")
        ).length,
        name === "bubble" ? 12 : 0,
        `${name} uses the expected pitch motion`
      );
    }

    await playConnectedSound("soft");
    assert.true(
      this.context.oscillators.at(-2).frequency.value < 400,
      "soft cues use the lower register"
    );

    await playConnectedSound("ethereal");
    const ethereal = this.context.oscillators.at(-2);
    assert.true(
      ethereal.stoppedAt - ethereal.startedAt > 0.4,
      "ethereal cues have a glassy sustain"
    );
  });

  test("ringtone themes have distinct call motifs", async function (assert) {
    const expected = {
      classic: { oscillators: 8, square: 0, sweeps: 0 },
      soft: { oscillators: 6, square: 0, sweeps: 0 },
      retro: { oscillators: 8, square: 8, sweeps: 0 },
      bubble: { oscillators: 4, square: 0, sweeps: 4 },
      ethereal: { oscillators: 4, square: 0, sweeps: 1 },
    };

    for (const [name, signature] of Object.entries(expected)) {
      this.context.oscillators = [];
      assert.true(await startRingtone(name), `${name} ringtone starts`);

      assert.strictEqual(
        this.context.oscillators.length,
        signature.oscillators,
        `${name} schedules its ringtone motif`
      );
      assert.strictEqual(
        this.context.oscillators.filter(({ type }) => type === "square").length,
        signature.square,
        `${name} uses the expected oscillator timbre`
      );
      assert.strictEqual(
        this.context.oscillators.filter(({ frequency }) =>
          frequency.events.some(({ method }) => method === "exponential")
        ).length,
        signature.sweeps,
        `${name} uses the expected pitch sweeps`
      );
    }
  });

  test("waiting themes are calmer variants of each ringtone", async function (assert) {
    const expectedOscillators = {
      classic: 2,
      soft: 2,
      retro: 2,
      bubble: 1,
      ethereal: 3,
    };

    for (const [name, oscillatorCount] of Object.entries(expectedOscillators)) {
      this.context.oscillators = [];
      assert.true(
        await startWaitingSound(1000, name),
        `${name} waiting sound starts`
      );
      assert.strictEqual(
        this.context.oscillators.length,
        oscillatorCount,
        `${name} schedules its waiting motif`
      );
    }
  });

  test("stopping a call sound silences scheduled audio", async function (assert) {
    await startRingtone("classic");
    const output = this.context.gains[0];

    stopCallSounds();

    assert.true(output.disconnected, "the shared call output is disconnected");
  });

  test("a stopped suspended start cannot ring later", async function (assert) {
    let resume;
    this.context.state = "suspended";
    this.context.resume = () =>
      new Promise((resolve) => {
        resume = resolve;
      });

    const start = startRingtone("soft");
    stopCallSounds();
    this.context.state = "running";
    resume();

    assert.false(await start, "the stale start is discarded");
    assert.strictEqual(
      this.context.oscillators.length,
      0,
      "no ringtone is scheduled after it was stopped"
    );
  });

  test("waiting sounds stop after their duration cap", async function (assert) {
    const clock = sinon.useFakeTimers({
      now: Date.now(),
      toFake: ["Date", "setTimeout", "clearTimeout"],
    });

    try {
      await startWaitingSound(10, "bubble");
      const output = this.context.gains[0];

      clock.tick(4000);

      assert.true(output.disconnected, "the capped waiting sound is stopped");
    } finally {
      clock.restore();
    }
  });
});
