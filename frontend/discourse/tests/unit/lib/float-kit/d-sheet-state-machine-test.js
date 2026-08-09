import { track, validateTag, valueForTag } from "@glimmer/validator";
import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import StateMachine from "discourse/float-kit/components/d-sheet/state-machine";
import {
  EVENTS,
  MACHINE_NAMES,
} from "discourse/float-kit/components/d-sheet/state-machine-events";
import StateMachineGroup from "discourse/float-kit/components/d-sheet/state-machine-group";
import {
  GUARDS,
  SHEET_MACHINES,
} from "discourse/float-kit/components/d-sheet/states";

function nextAnimationFrame() {
  return new Promise((resolve) => requestAnimationFrame(resolve));
}

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

  test("reactive nested transitions do not re-enter their parent state", async function (assert) {
    const machine = new StateMachine(
      {
        states: {
          open: {
            machines: {
              name: "status",
              initial: "idle",
              states: {
                idle: { messages: { START: "running" } },
                running: {},
              },
            },
          },
        },
      },
      "open"
    );
    const notifications = [];

    for (const timing of ["immediate", "before-paint", "after-paint"]) {
      machine.subscribe({
        timing,
        state: "open",
        callback: () => notifications.push(`open-${timing}`),
      });
      machine.subscribe({
        timing,
        state: "open.status:running",
        callback: () => notifications.push(`status-${timing}`),
      });
    }

    machine.send("START");
    await settled();
    await nextAnimationFrame();

    assert.deepEqual(
      notifications,
      ["status-immediate", "status-before-paint", "status-after-paint"],
      "only the nested state runs its entry actions"
    );

    machine.cleanup();
  });

  test("timed actions only run for the latest uninterrupted state entry", async function (assert) {
    const machine = new StateMachine(
      {
        states: {
          idle: { messages: { OPEN: "open" } },
          open: { messages: { RESET: "idle" } },
        },
      },
      "idle"
    );
    const notifications = [];

    for (const timing of ["before-paint", "after-paint"]) {
      machine.subscribe({
        timing,
        state: "open",
        callback: (message) =>
          notifications.push(`${timing}-${message.sequence}`),
      });
    }

    machine.send({ type: "OPEN", sequence: 1 });
    machine.send("RESET");
    machine.send({ type: "OPEN", sequence: 2 });
    await settled();
    await nextAnimationFrame();

    assert.deepEqual(
      notifications,
      ["before-paint-2", "after-paint-2"],
      "a re-entry supersedes callbacks queued by the previous entry"
    );

    machine.send("RESET");
    machine.send({ type: "OPEN", sequence: 3 });
    machine.send("RESET");
    await settled();
    await nextAnimationFrame();

    assert.deepEqual(
      notifications,
      ["before-paint-2", "after-paint-2"],
      "leaving the state cancels callbacks that have not run"
    );

    machine.cleanup();
  });

  test("timed action guards are evaluated when the action runs", async function (assert) {
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
    let allowed = false;
    const isAllowed = () => allowed;

    for (const timing of ["before-paint", "after-paint"]) {
      machine.subscribe({
        timing,
        state: "open",
        guard: isAllowed,
        callback: () => notifications.push(timing),
      });
    }

    machine.send("OPEN");
    allowed = true;
    await settled();
    await nextAnimationFrame();

    assert.deepEqual(
      notifications,
      ["before-paint", "after-paint"],
      "a state entry schedules its actions before their dynamic guard resolves"
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

  test("opening ignores close requests and NEXT enters open", function (assert) {
    const group = new StateMachineGroup(SHEET_MACHINES, { guards: GUARDS });
    const openness = group.getMachine(MACHINE_NAMES.OPENNESS);

    openness.send({ type: EVENTS.READY_TO_OPEN, skipOpening: false });
    openness.send(EVENTS.CLOSE);

    assert.deepEqual(
      openness.toStrings(),
      ["opening"],
      "a close request neither changes nor augments the opening state"
    );

    openness.send(EVENTS.NEXT);

    assert.strictEqual(
      openness.current,
      "open",
      "opening completion always resolves to open"
    );

    group.cleanup();
  });

  test("ended swipe state resets before the next presentation", function (assert) {
    const group = new StateMachineGroup(SHEET_MACHINES, { guards: GUARDS });
    const openness = group.getMachine(MACHINE_NAMES.OPENNESS);

    openness.send({ type: EVENTS.READY_TO_OPEN, skipOpening: true });
    openness.send(EVENTS.SWIPE_START);
    openness.send(EVENTS.SWIPE_END);
    openness.send(EVENTS.SWIPE_RESET);

    assert.true(
      openness.matches("open.swipe:unstarted"),
      "the next gesture starts from Silk's initial swipe state"
    );

    group.cleanup();
  });

  test("group toStrings tracks each machine state directly", function (assert) {
    const group = new StateMachineGroup([
      {
        name: "main",
        initial: "idle",
        states: {
          idle: { messages: { MAIN: "open" } },
          open: {},
        },
      },
      {
        name: "nested",
        initial: "open",
        states: {
          open: {
            machines: {
              name: "status",
              initial: "off",
              states: {
                off: { messages: { NESTED: "on" } },
                on: {},
              },
            },
          },
        },
      },
    ]);

    let tag = track(() => group.toStrings());
    let snapshot = valueForTag(tag);

    group.send("NESTED");

    assert.false(
      validateTag(tag, snapshot),
      "a nested machine transition invalidates toStrings"
    );

    tag = track(() => group.toStrings());
    snapshot = valueForTag(tag);

    group.send("MAIN");

    assert.false(
      validateTag(tag, snapshot),
      "a top-level machine transition invalidates toStrings"
    );

    group.cleanup();
  });

  test("group cleanup destroys every machine and cancels their queued subscribers", async function (assert) {
    const definitions = ["first", "second"].map((name) => ({
      name,
      initial: "idle",
      states: {
        idle: { messages: { OPEN: "open" } },
        open: { messages: { RESET: "idle" } },
      },
    }));
    const group = new StateMachineGroup(definitions);
    const notifications = [];

    for (const [index, { name }] of definitions.entries()) {
      group.getMachine(name).subscribe({
        timing: index === 0 ? "before-paint" : "after-paint",
        state: "open",
        callback: () => notifications.push(name),
      });
    }

    group.send("OPEN");
    group.cleanup();
    await settled();

    assert.deepEqual(
      notifications,
      [],
      "no machine delivers a queued notification after group cleanup"
    );

    for (const { name } of definitions) {
      assert.false(
        group.getMachine(name).send("RESET"),
        `${name} rejects messages after group cleanup`
      );
    }
  });
});
