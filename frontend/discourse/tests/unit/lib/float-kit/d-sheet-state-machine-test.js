import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import StateMachine from "discourse/float-kit/components/d-sheet/state-machine";

module("Unit | FloatKit | d-sheet state machine", function (hooks) {
  setupTest(hooks);

  test("guards receive send context before automatic transitions", function (assert) {
    const machine = new StateMachine(
      {
        states: {
          idle: {
            messages: {
              START: { guard: "allowed", target: "starting" },
            },
          },
          starting: { messages: { "": "running" } },
          running: {},
        },
      },
      "idle",
      {
        guards: {
          allowed: (_states, message) => message.allowed,
        },
      }
    );

    assert.false(machine.send("START"));
    assert.strictEqual(machine.current, "idle");

    assert.true(machine.send("START", { allowed: true }));
    assert.strictEqual(machine.current, "running");
  });

  test("single nested machine definitions transition automatically", function (assert) {
    const machine = new StateMachine(
      {
        states: {
          open: {
            machines: {
              name: "status",
              initial: "idle",
              states: {
                idle: { messages: { START: "starting" } },
                starting: { messages: { "": "running" } },
                running: {},
              },
            },
          },
        },
      },
      "open"
    );

    assert.true(machine.send("START"));
    assert.deepEqual(machine.toStrings(), ["open", "open.status:running"]);
  });

  test("silent nested transitions run exact immediate actions only", async function (assert) {
    const machine = new StateMachine(
      {
        states: {
          open: {
            machines: {
              name: "swipe",
              silentOnly: true,
              initial: "ended",
              states: {
                ended: { messages: { START: "ongoing" } },
                ongoing: { messages: { END: "ended" } },
              },
            },
          },
        },
      },
      "open"
    );
    const notifications = [];

    machine.subscribe({
      timing: "immediate",
      state: "open.swipe:ongoing",
      callback: () => notifications.push("swipe-enter"),
    });
    machine.subscribe({
      timing: "immediate",
      type: "exit",
      state: "open.swipe:ongoing",
      callback: () => notifications.push("swipe-exit"),
    });
    machine.subscribe({
      timing: "immediate",
      state: "open",
      callback: () => notifications.push("open-enter"),
    });
    machine.subscribe({
      timing: "before-paint",
      state: "open",
      callback: () => notifications.push("open-timed"),
    });

    machine.send("START");
    machine.send("END");
    await settled();

    assert.deepEqual(
      notifications,
      ["swipe-enter", "swipe-exit"],
      "silent transitions notify their exact boundaries without re-running parent subscriptions"
    );

    machine.cleanup();
  });

  test("cleanup cancels queued subscriber notifications", async function (assert) {
    const machine = new StateMachine(
      {
        states: {
          idle: { messages: { OPEN: "open" } },
          open: {},
        },
      },
      "idle"
    );
    const notifications = [];

    machine.subscribe({
      timing: "before-paint",
      state: "open",
      callback: () => notifications.push("before-paint"),
    });
    machine.subscribe({
      timing: "after-paint",
      state: "open",
      callback: () => notifications.push("after-paint"),
    });

    machine.send("OPEN");
    machine.cleanup();
    await settled();

    assert.deepEqual(
      notifications,
      [],
      "queued notifications do not survive cleanup"
    );
    assert.false(
      machine.send("OPEN"),
      "a destroyed machine rejects new messages"
    );
  });
});
