import { track, validateTag, valueForTag } from "@glimmer/validator";
import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import StateMachine from "discourse/float-kit/components/d-sheet/state-machine";
import {
  EVENTS,
  MACHINE_NAMES,
} from "discourse/float-kit/components/d-sheet/state-machine-events";
import {
  GUARDS,
  POSITION_MACHINES,
  SHEET_MACHINES,
} from "discourse/float-kit/components/d-sheet/states";

function stubAnimationFrames() {
  const callbacks = new Map();
  let nextId = 1;

  sinon.stub(window, "requestAnimationFrame").callsFake((callback) => {
    const id = nextId++;
    callbacks.set(id, callback);
    return id;
  });
  sinon.stub(window, "cancelAnimationFrame").callsFake((id) => {
    callbacks.delete(id);
  });

  return {
    get size() {
      return callbacks.size;
    },
    flush(timestamp = 0) {
      const pendingCallbacks = [...callbacks];

      for (const [id, callback] of pendingCallbacks) {
        callbacks.delete(id);
        callback(timestamp);
      }
    },
  };
}

async function flushAnimationFrames(queue) {
  for (let iteration = 0; iteration < 10; iteration++) {
    await settled();

    if (queue.size === 0) {
      return;
    }

    queue.flush(iteration);
  }

  throw new Error("d-sheet state machine animation frames did not settle");
}

function booleanMachine(name, { silentOnly = false } = {}) {
  return {
    name,
    silentOnly,
    initial: "false",
    states: {
      false: { messages: { TO_TRUE: "true" } },
      true: { messages: { TO_FALSE: "false" } },
    },
  };
}

module("Unit | FloatKit | d-sheet state machine", function (hooks) {
  setupTest(hooks);
  hooks.afterEach(() => sinon.restore());

  test("initializes every active parallel and nested region", function (assert) {
    const machine = new StateMachine(SHEET_MACHINES, { guards: GUARDS });

    assert.deepEqual(
      machine.toStrings(),
      [
        "staging:none",
        "longRunning:false",
        "skipOpening:false",
        "skipClosing:false",
        "openness:closed",
        "openness:closed.status:safe-to-unmount",
        "scrollContainerTouch:ended",
        "backStuck:false",
        "frontStuck:false",
        "elementsReady:false",
      ],
      "the initial snapshot contains every active state path"
    );

    machine.cleanup();
  });

  test("empty events only transition when explicitly sent", function (assert) {
    const machine = new StateMachine([
      {
        name: "flow",
        initial: "idle",
        states: {
          idle: { messages: { START: "transient" } },
          transient: { messages: { "": "complete" } },
          complete: {},
        },
      },
    ]);
    const flow = machine.select("flow");

    flow.send("START");

    assert.strictEqual(
      flow.current,
      "transient",
      "entering a state does not implicitly dispatch an empty event"
    );

    flow.send("");

    assert.strictEqual(
      flow.current,
      "complete",
      "an explicit empty event takes the transition"
    );

    machine.cleanup();
  });

  test("an entry action can queue an explicit transient transition", function (assert) {
    const machine = new StateMachine([
      {
        name: "flow",
        initial: "idle",
        states: {
          idle: { messages: { START: "transient" } },
          transient: { messages: { "": "complete" } },
          complete: {},
        },
      },
    ]);
    const flow = machine.select("flow");
    const entered = [];

    flow.subscribe({
      state: "transient",
      callback: () => {
        entered.push(flow.current);
        flow.send("");
      },
    });
    flow.subscribe({
      state: "complete",
      callback: () => entered.push(flow.current),
    });

    flow.send("START");

    assert.deepEqual(
      entered,
      ["transient", "complete"],
      "the transient state is observable before its queued event runs"
    );
    assert.strictEqual(
      flow.current,
      "complete",
      "the queued event runs after the current transition actions"
    );

    machine.cleanup();
  });

  test("transition actions can target an explicit empty event", function (assert) {
    const machine = new StateMachine([
      {
        name: "flow",
        initial: "transient",
        states: {
          transient: {
            messages: { "": "complete", CANCEL: "cancelled" },
          },
          complete: { messages: { RESET: "transient" } },
          cancelled: {},
        },
      },
    ]);
    const flow = machine.select("flow");
    const notifications = [];

    flow.subscribe({
      type: "transition",
      state: "transient",
      transition: "",
      callback: (message) => notifications.push(message.type),
    });

    flow.send("");
    flow.send("RESET");
    flow.send("CANCEL");

    assert.deepEqual(
      notifications,
      [""],
      "the empty transition filter does not match other events"
    );

    machine.cleanup();
  });

  test("parallel transitions use one previous state snapshot", function (assert) {
    const machine = new StateMachine(
      [
        {
          name: "first",
          initial: "idle",
          states: {
            idle: { messages: { START: "active" } },
            active: {},
          },
        },
        {
          name: "second",
          initial: "idle",
          states: {
            idle: {
              messages: {
                START: { guard: "firstWasIdle", target: "active" },
              },
            },
            active: {},
          },
        },
      ],
      {
        guards: {
          firstWasIdle: (states, message) =>
            states.includes("first:idle") && message.allowed,
        },
      }
    );

    machine.send({ type: "START", allowed: true });

    assert.deepEqual(
      machine.toStrings(),
      ["first:active", "second:active"],
      "both regions transition from the same pre-event snapshot"
    );

    machine.cleanup();
  });

  test("selector events only reach the selected region", function (assert) {
    const machine = new StateMachine([
      booleanMachine("first"),
      booleanMachine("second"),
    ]);
    const first = machine.select("first");

    first.send("TO_TRUE");

    assert.deepEqual(
      machine.toStrings(),
      ["first:true", "second:false"],
      "the targeted event leaves sibling regions unchanged"
    );

    machine.send("TO_TRUE");

    assert.deepEqual(
      machine.toStrings(),
      ["first:true", "second:true"],
      "an unqualified event is offered to every active region"
    );

    machine.cleanup();
  });

  test("supports recursive child regions and restores their initial states", function (assert) {
    const machine = new StateMachine([
      {
        name: "openness",
        initial: "open",
        states: {
          open: {
            machines: [
              {
                name: "scroll",
                initial: "ended",
                states: {
                  ended: {
                    messages: { SCROLL_START: "ongoing" },
                    machines: [booleanMachine("afterPaintEffectsRun")],
                  },
                  ongoing: { messages: { SCROLL_END: "ended" } },
                },
              },
            ],
          },
        },
      },
    ]);
    const openness = machine.select("openness");

    assert.deepEqual(
      openness.toStrings(),
      [
        "open",
        "open.scroll:ended",
        "open.scroll:ended.afterPaintEffectsRun:false",
      ],
      "the selector exposes all active descendant paths"
    );

    machine.send({
      machine: "openness:open.scroll:ended.afterPaintEffectsRun",
      type: "TO_TRUE",
    });
    assert.true(
      openness.matches("open.scroll:ended.afterPaintEffectsRun:true"),
      "a third-level child can transition"
    );

    openness.send({
      machine: "openness:open.scroll",
      type: "SCROLL_START",
    });
    assert.deepEqual(
      openness.toStrings(),
      ["open", "open.scroll:ongoing"],
      "leaving the parent removes its child region"
    );

    openness.send({
      machine: "openness:open.scroll",
      type: "SCROLL_END",
    });
    assert.true(
      openness.matches("open.scroll:ended.afterPaintEffectsRun:false"),
      "re-entering the parent restores the child initial state"
    );

    machine.cleanup();
  });

  test("newly entered regions do not consume the current event", function (assert) {
    const machine = new StateMachine([
      {
        name: "openness",
        initial: "closed",
        states: {
          closed: { messages: { OPEN: "open" } },
          open: {
            machines: [
              {
                name: "evaluation",
                silentOnly: true,
                initial: "false",
                states: {
                  false: { messages: { OPEN: "true" } },
                  true: {},
                },
              },
            ],
          },
        },
      },
    ]);
    const openness = machine.select("openness");

    openness.send("OPEN");

    assert.true(
      openness.matches("open.evaluation:false"),
      "the event only applies to states active at the start of the transition"
    );

    machine.cleanup();
  });

  test("runs exits, source transitions, and entries in order", function (assert) {
    const machine = new StateMachine([
      {
        name: "first",
        initial: "idle",
        states: {
          idle: { messages: { START: "active" } },
          active: {},
        },
      },
      {
        name: "second",
        initial: "idle",
        states: {
          idle: { messages: { START: "active" } },
          active: {},
        },
      },
    ]);
    const first = machine.select("first");
    const second = machine.select("second");
    const calls = [];
    const record = (label) => {
      assert.true(first.matches("active"), `${label} sees first committed`);
      assert.true(second.matches("active"), `${label} sees second committed`);
      calls.push(label);
    };
    const effectGuard = (states, message) =>
      states.includes("first:idle") && message.allowed;

    first.subscribe({
      type: "exit",
      state: "idle",
      guard: effectGuard,
      callback: () => record("first-exit"),
    });
    second.subscribe({
      type: "exit",
      state: "idle",
      callback: () => record("second-exit"),
    });
    first.subscribe({
      type: "transition",
      state: "idle",
      transition: "START",
      callback: () => record("first-transition"),
    });
    second.subscribe({
      type: "transition",
      state: "idle",
      transition: "START",
      callback: () => record("second-transition"),
    });
    first.subscribe({
      state: "active",
      callback: () => record("first-entry"),
    });
    second.subscribe({
      state: "active",
      callback: () => record("second-entry"),
    });

    machine.send({ type: "START", allowed: true });

    assert.deepEqual(
      calls,
      [
        "first-exit",
        "second-exit",
        "first-transition",
        "second-transition",
        "first-entry",
        "second-entry",
      ],
      "each action phase completes before the next begins"
    );

    machine.cleanup();
  });

  test("cross-level transitions run actions for every exited state", function (assert) {
    const machine = new StateMachine([
      {
        name: "flow",
        initial: "active",
        states: {
          active: {
            machines: [
              {
                name: "phase",
                initial: "idle",
                states: {
                  idle: { messages: { FINISH: "flow:done" } },
                },
              },
            ],
          },
          done: {},
        },
      },
    ]);
    const flow = machine.select("flow");
    const notifications = [];

    flow.subscribe({
      type: "transition",
      state: "active",
      transition: "FINISH",
      callback: () => notifications.push("parent-transition"),
    });

    flow.sendUnscoped("FINISH");

    assert.deepEqual(
      notifications,
      ["parent-transition"],
      "an ancestor transition action runs when a descendant exits it"
    );

    machine.cleanup();
  });

  test("reentrant events share one FIFO across parallel regions", function (assert) {
    const definitions = ["first", "second"].map((name) => ({
      name,
      initial: "idle",
      states: {
        idle: { messages: { FIRST: "active" } },
        active: { messages: { SECOND: "done" } },
        done: {},
      },
    }));
    const machine = new StateMachine(definitions);

    machine.select("first").subscribe({
      state: "active",
      callback: () => machine.send("SECOND"),
    });

    machine.send("FIRST");

    assert.deepEqual(
      machine.toStrings(),
      ["first:done", "second:done"],
      "the queued event runs after every region handles the first event"
    );

    machine.cleanup();
  });

  test("silent regions run immediate actions without publishing", function (assert) {
    const machine = new StateMachine([
      booleanMachine("flag", { silentOnly: true }),
    ]);
    const flag = machine.select("flag");
    const reactiveFlag = machine.select("flag", { includeSilentUpdates: true });
    const notifications = [];

    flag.subscribe({
      state: "true",
      callback: () => notifications.push("entered"),
    });

    const machineTag = track(() => machine.toStrings());
    const machineSnapshot = valueForTag(machineTag);
    const projectedTag = track(() => reactiveFlag.matches("false"));
    const projectedSnapshot = valueForTag(projectedTag);

    flag.send("TO_TRUE");

    assert.deepEqual(
      notifications,
      ["entered"],
      "silent transitions still run exact immediate actions"
    );
    assert.true(
      validateTag(machineTag, machineSnapshot),
      "the default published snapshot remains valid"
    );
    assert.false(
      validateTag(projectedTag, projectedSnapshot),
      "an explicit reactive projection observes silent changes"
    );
    assert.true(flag.matches("true"), "imperative reads expose the new state");

    machine.cleanup();
  });

  test("selectors only invalidate for changes in their region", function (assert) {
    const machine = new StateMachine([
      booleanMachine("first"),
      booleanMachine("second"),
    ]);
    const first = machine.select("first");
    const second = machine.select("second");
    const firstTag = track(() => first.current);
    const firstSnapshot = valueForTag(firstTag);
    const actorTag = track(() => machine.toStrings());
    const actorSnapshot = valueForTag(actorTag);

    second.send("TO_TRUE");

    assert.true(
      validateTag(firstTag, firstSnapshot),
      "an unrelated parallel region preserves the selector tag"
    );
    assert.false(
      validateTag(actorTag, actorSnapshot),
      "the actor-wide snapshot still publishes the transition"
    );

    first.send("TO_TRUE");

    assert.false(
      validateTag(firstTag, firstSnapshot),
      "the selector invalidates when its own region changes"
    );

    machine.cleanup();
  });

  test("selectors preserve their identity when a queue returns to the published state", function (assert) {
    const machine = new StateMachine([
      {
        name: "flow",
        initial: "idle",
        states: {
          idle: { messages: { START: "active" } },
          active: { messages: { RESET: "idle" } },
        },
      },
    ]);
    const flow = machine.select("flow");
    const flowTag = track(() => flow.current);
    const flowSnapshot = valueForTag(flowTag);
    const actorTag = track(() => machine.toStrings());
    const actorSnapshot = valueForTag(actorTag);

    flow.subscribe({
      state: "active",
      callback: () => flow.send("RESET"),
    });

    flow.send("START");

    assert.strictEqual(flow.current, "idle");
    assert.true(
      validateTag(flowTag, flowSnapshot),
      "the final selected value retains its identity"
    );
    assert.false(
      validateTag(actorTag, actorSnapshot),
      "the actor still publishes the reactive queue"
    );

    machine.cleanup();
  });

  test("nested selectors publish reactive and silent descendants independently", function (assert) {
    const machine = new StateMachine([
      {
        name: "parent",
        initial: "open",
        states: {
          open: {
            machines: [
              booleanMachine("reactive"),
              booleanMachine("silent", { silentOnly: true }),
            ],
          },
        },
      },
    ]);
    const parent = machine.select("parent");
    const publishedParentTag = track(() => parent.toStrings());
    const publishedParentSnapshot = valueForTag(publishedParentTag);
    const liveParent = machine.select("parent", {
      includeSilentUpdates: true,
    });
    const liveParentTag = track(() => liveParent.toStrings());
    const liveParentSnapshot = valueForTag(liveParentTag);

    machine.send({
      machine: "parent:open.silent",
      type: "TO_TRUE",
    });

    assert.true(
      validateTag(publishedParentTag, publishedParentSnapshot),
      "a silent descendant does not publish its parent selector"
    );
    assert.false(
      validateTag(liveParentTag, liveParentSnapshot),
      "the live parent selector observes a silent descendant"
    );

    machine.send({
      machine: "parent:open.reactive",
      type: "TO_TRUE",
    });

    assert.false(
      validateTag(publishedParentTag, publishedParentSnapshot),
      "a reactive descendant publishes its parent selector"
    );

    machine.cleanup();
  });

  test("exiting a parent publishes its inactive silent child", function (assert) {
    const machine = new StateMachine([
      {
        name: "parent",
        initial: "open",
        states: {
          open: {
            messages: { CLOSE: "closed" },
            machines: [booleanMachine("silent", { silentOnly: true })],
          },
          closed: {},
        },
      },
    ]);
    const child = machine.select("parent:open.silent");
    const childTag = track(() => child.current);
    const childSnapshot = valueForTag(childTag);

    child.send("TO_TRUE");
    assert.true(
      validateTag(childTag, childSnapshot),
      "the silent child change remains unpublished"
    );

    machine.select("parent").send("CLOSE");

    assert.false(
      validateTag(childTag, childSnapshot),
      "the reactive parent exit publishes the inactive child"
    );
    assert.strictEqual(child.current, null);

    machine.cleanup();
  });

  test("a later reactive transition publishes accumulated silent changes", function (assert) {
    const machine = new StateMachine([
      booleanMachine("reactive"),
      booleanMachine("silent", { silentOnly: true }),
    ]);
    const silent = machine.select("silent");
    const silentTag = track(() => silent.current);
    const silentSnapshot = valueForTag(silentTag);

    silent.send("TO_TRUE");

    assert.true(
      validateTag(silentTag, silentSnapshot),
      "the silent-only transition remains unpublished"
    );

    machine.select("reactive").send("TO_TRUE");

    assert.false(
      validateTag(silentTag, silentSnapshot),
      "the next actor publication includes the accumulated silent change"
    );
    assert.strictEqual(silent.current, "true");

    machine.cleanup();
  });

  test("immediate actions observe the previously processed message", function (assert) {
    const machine = new StateMachine([
      {
        name: "flow",
        initial: "idle",
        states: {
          idle: { messages: { START: "active" } },
          active: {},
        },
      },
    ]);
    const flow = machine.select("flow");
    let messageDuringAction;

    flow.send({ type: "IGNORED", sequence: 1 });
    flow.subscribe({
      state: "active",
      callback: () => {
        messageDuringAction = flow.lastProcessedMessage;
      },
    });

    flow.send({ type: "START", sequence: 2 });

    assert.deepEqual(
      messageDuringAction,
      { type: "IGNORED", sequence: 1, machine: "flow" },
      "the current message is recorded after its immediate actions"
    );
    assert.deepEqual(flow.lastProcessedMessage, {
      type: "START",
      sequence: 2,
      machine: "flow",
    });

    machine.cleanup();
  });

  test("silent timed actions wait for a reactive publication", async function (assert) {
    const animationFrames = stubAnimationFrames();
    const machine = new StateMachine([
      booleanMachine("reactive"),
      booleanMachine("flag", { silentOnly: true }),
    ]);
    const flag = machine.select("flag");
    const notifications = [];

    for (const timing of ["before-paint", "after-paint"]) {
      flag.subscribe({
        timing,
        state: "true",
        callback: () => notifications.push(timing),
      });
    }

    flag.send("TO_TRUE");
    await flushAnimationFrames(animationFrames);

    assert.deepEqual(
      notifications,
      [],
      "a silent-only state change does not schedule render-timed actions"
    );

    machine.select("reactive").send("TO_TRUE");
    await flushAnimationFrames(animationFrames);

    assert.deepEqual(
      notifications,
      ["before-paint", "after-paint"],
      "the next reactive snapshot publishes the accumulated silent entry"
    );

    machine.cleanup();
  });

  test("timed actions only run for the latest uninterrupted entry", async function (assert) {
    const animationFrames = stubAnimationFrames();
    const machine = new StateMachine([
      {
        name: "flow",
        initial: "idle",
        states: {
          idle: { messages: { OPEN: "open" } },
          open: { messages: { RESET: "idle" } },
        },
      },
    ]);
    const flow = machine.select("flow");
    const notifications = [];

    for (const timing of ["before-paint", "after-paint"]) {
      flow.subscribe({
        timing,
        state: "open",
        callback: (message) =>
          notifications.push(`${timing}-${message.sequence}`),
      });
    }

    flow.send({ type: "OPEN", sequence: 1 });
    flow.send("RESET");
    flow.send({ type: "OPEN", sequence: 2 });
    await flushAnimationFrames(animationFrames);

    assert.deepEqual(
      notifications,
      ["before-paint-2", "after-paint-2"],
      "re-entry supersedes callbacks from the interrupted entry"
    );

    flow.send("RESET");
    flow.send({ type: "OPEN", sequence: 3 });
    flow.send("RESET");
    await flushAnimationFrames(animationFrames);

    assert.deepEqual(
      notifications,
      ["before-paint-2", "after-paint-2"],
      "leaving the state cancels callbacks that have not run"
    );

    machine.cleanup();
  });

  test("timed action guards are evaluated when the action runs", async function (assert) {
    const animationFrames = stubAnimationFrames();
    const machine = new StateMachine([
      {
        name: "flow",
        initial: "idle",
        states: {
          idle: { messages: { OPEN: "open" } },
          open: {},
        },
      },
    ]);
    const flow = machine.select("flow");
    const notifications = [];
    let allowed = false;
    const isAllowed = () => allowed;

    for (const timing of ["before-paint", "after-paint"]) {
      flow.subscribe({
        timing,
        state: "open",
        guard: isAllowed,
        callback: () => notifications.push(timing),
      });
    }

    flow.send("OPEN");
    allowed = true;
    await flushAnimationFrames(animationFrames);

    assert.deepEqual(
      notifications,
      ["before-paint", "after-paint"],
      "state entry schedules actions before their dynamic guards resolve"
    );

    machine.cleanup();
  });

  test("pending timed actions observe the latest reentrant message", async function (assert) {
    const animationFrames = stubAnimationFrames();
    const machine = new StateMachine([
      {
        name: "flow",
        initial: "idle",
        states: {
          idle: { messages: { OPEN: "open" } },
          open: { messages: { RESET: "idle" } },
        },
      },
    ]);
    const flow = machine.select("flow");
    const notifications = [];

    flow.subscribe({
      state: "idle",
      callback: () => flow.send({ type: "OPEN", sequence: 2 }),
    });
    flow.subscribe({
      timing: "after-paint",
      state: "open",
      callback: (message) => notifications.push(message.sequence),
    });

    flow.send({ type: "OPEN", sequence: 1 });
    flow.send("RESET");
    await flushAnimationFrames(animationFrames);

    assert.deepEqual(
      notifications,
      [2],
      "an unchanged published selection keeps its effect with current context"
    );

    machine.cleanup();
  });

  test("no-op events preserve pending timed actions", async function (assert) {
    const animationFrames = stubAnimationFrames();
    const machine = new StateMachine([
      {
        name: "flow",
        initial: "idle",
        states: {
          idle: { messages: { OPEN: "open" } },
          open: {},
        },
      },
    ]);
    const flow = machine.select("flow");
    const notifications = [];

    flow.subscribe({
      timing: "after-paint",
      state: "open",
      callback: () => notifications.push("open"),
    });

    flow.send("OPEN");
    flow.send("IGNORED");
    await flushAnimationFrames(animationFrames);

    assert.deepEqual(
      notifications,
      ["open"],
      "a no-op neither cancels nor reschedules the pending action"
    );

    machine.cleanup();
  });

  test("unsubscribe cancels scheduled timed actions", async function (assert) {
    const animationFrames = stubAnimationFrames();
    const machine = new StateMachine([
      {
        name: "flow",
        initial: "idle",
        states: {
          idle: { messages: { OPEN: "open" } },
          open: {},
        },
      },
    ]);
    const flow = machine.select("flow");
    const notifications = [];
    const unsubscribers = ["before-paint", "after-paint"].map((timing) =>
      flow.subscribe({
        timing,
        state: "open",
        callback: () => notifications.push(timing),
      })
    );

    flow.send("OPEN");
    unsubscribers.forEach((unsubscribe) => unsubscribe());
    await flushAnimationFrames(animationFrames);

    assert.deepEqual(
      notifications,
      [],
      "neither scheduled timing delivers an unsubscribed callback"
    );

    machine.cleanup();
  });

  test("cleanup cancels pending actions and rejects new messages", async function (assert) {
    const animationFrames = stubAnimationFrames();
    const machine = new StateMachine([
      {
        name: "flow",
        initial: "idle",
        states: {
          idle: { messages: { OPEN: "open" } },
          open: {},
        },
      },
    ]);
    const notifications = [];

    machine.select("flow").subscribe({
      timing: "after-paint",
      state: "open",
      callback: () => notifications.push("open"),
    });

    machine.send("OPEN");
    machine.cleanup();
    machine.cleanup();
    await flushAnimationFrames(animationFrames);

    assert.deepEqual(notifications, [], "no pending action survives cleanup");
    assert.false(machine.send("OPEN"), "a destroyed actor rejects messages");
  });

  test("validates named guards and transition targets", function (assert) {
    assert.throws(
      () =>
        new StateMachine([
          {
            name: "flow",
            initial: "idle",
            states: {
              idle: {
                messages: {
                  START: { guard: "missing", target: "active" },
                },
              },
              active: {},
            },
          },
        ]),
      /Unknown guard 'missing'/,
      "an unresolved guard is rejected"
    );

    assert.throws(
      () =>
        new StateMachine([
          {
            name: "flow",
            initial: "idle",
            states: {
              idle: { messages: { START: "missing" } },
            },
          },
        ]),
      /Unknown transition target 'flow:missing'/,
      "an invalid target is rejected"
    );
  });

  test("a throwing action does not wedge the event queue", function (assert) {
    const machine = new StateMachine([
      {
        name: "flow",
        initial: "idle",
        states: {
          idle: { messages: { START: "active" } },
          active: { messages: { RESET: "idle" } },
        },
      },
    ]);
    const flow = machine.select("flow");
    const unsubscribe = flow.subscribe({
      state: "active",
      callback: () => {
        throw new Error("action failed");
      },
    });

    assert.throws(
      () => flow.send("START"),
      /action failed/,
      "the action error reaches the caller"
    );
    unsubscribe();

    assert.true(flow.send("RESET"), "the actor accepts a later message");
    assert.strictEqual(flow.current, "idle", "the later transition completes");

    machine.cleanup();
  });

  test("sheet definitions preserve explicit pending and recursive scroll states", function (assert) {
    const machine = new StateMachine(SHEET_MACHINES, { guards: GUARDS });
    const openness = machine.select(MACHINE_NAMES.OPENNESS);

    openness.send({ type: EVENTS.READY_TO_OPEN, skipOpening: true });

    assert.true(openness.matches("open"), "the sheet opens without animation");
    assert.true(
      openness.matches("open.scroll:ended.afterPaintEffectsRun:false"),
      "the scroll effect marker is initialized under the ended state"
    );

    openness.send(EVENTS.SWIPED_OUT);
    assert.true(
      openness.matches("closed.status:pending"),
      "closing enters the observable pending state"
    );

    openness.send({ machine: "openness:closed.status", type: "" });
    assert.true(
      openness.matches("closed.status:safe-to-unmount"),
      "the targeted empty event completes the pending state"
    );

    machine.cleanup();
  });

  test("an animated pending reopen exposes flushing before preparing", function (assert) {
    const machine = new StateMachine(SHEET_MACHINES, { guards: GUARDS });
    const openness = machine.select(MACHINE_NAMES.OPENNESS);

    openness.send({ type: EVENTS.READY_TO_OPEN, skipOpening: true });
    openness.send(EVENTS.SWIPED_OUT);
    machine.send(EVENTS.OPEN);

    assert.true(
      openness.matches("closed.status:flushing-to-preparing-opening"),
      "the animated reopen enters its observable flushing state"
    );
    assert.false(
      openness.matches("closed.status:preparing-opening"),
      "preparing waits for the explicit empty event"
    );

    openness.send({ machine: "openness:closed.status", type: "" });

    assert.true(
      openness.matches("closed.status:preparing-opening"),
      "the empty event advances the animated reopen to preparing"
    );

    machine.cleanup();
  });

  test("a skipped pending reopen exposes flushing before preparing", function (assert) {
    const machine = new StateMachine(SHEET_MACHINES, { guards: GUARDS });
    const openness = machine.select(MACHINE_NAMES.OPENNESS);
    const skipOpening = machine.select(MACHINE_NAMES.SKIP_OPENING);

    openness.send({ type: EVENTS.READY_TO_OPEN, skipOpening: true });
    openness.send(EVENTS.SWIPED_OUT);
    skipOpening.send(EVENTS.TO_TRUE);
    machine.send(EVENTS.OPEN);

    assert.true(
      openness.matches("closed.status:flushing-to-preparing-open"),
      "the skipped reopen enters its observable flushing state"
    );
    assert.false(
      openness.matches("closed.status:preparing-open"),
      "preparing waits for the explicit empty event"
    );

    openness.send({ machine: "openness:closed.status", type: "" });

    assert.true(
      openness.matches("closed.status:preparing-open"),
      "the empty event advances the skipped reopen to preparing"
    );

    machine.cleanup();
  });

  test("position definitions expose come-back before its empty event", function (assert) {
    const machine = new StateMachine(POSITION_MACHINES, { guards: GUARDS });
    const position = machine.select(MACHINE_NAMES.POSITION);
    const entered = [];

    position.send(EVENTS.READY_TO_GO_FRONT, { skipOpening: true });
    position.sendUnscoped(EVENTS.READY_TO_GO_DOWN, { skipOpening: true });
    position.subscribe({
      state: "covered.status:come-back",
      callback: () => {
        entered.push(position.toStrings());
        position.sendUnscoped("");
      },
    });

    position.sendUnscoped(EVENTS.READY_TO_GO_DOWN, { skipOpening: true });

    assert.deepEqual(
      entered,
      [["covered", "covered.status:come-back"]],
      "the entry action observes the transient state"
    );
    assert.true(
      position.matches("covered.status:idle"),
      "the queued empty event returns the status to idle"
    );

    machine.cleanup();
  });
});
