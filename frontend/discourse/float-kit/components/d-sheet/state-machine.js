import { tracked } from "@glimmer/tracking";
import { cancel, schedule } from "@ember/runloop";
import StateMachineDefinition from "./state-machine-definition";

const TIMING = Object.freeze({
  AFTER_PAINT: "after-paint",
  BEFORE_PAINT: "before-paint",
  IMMEDIATE: "immediate",
});

const TYPE = Object.freeze({
  ENTER: "enter",
  EXIT: "exit",
  TRANSITION: "transition",
});

function asArray(value) {
  return Array.isArray(value) ? value : [value];
}

function includesAny(values, candidates) {
  return candidates.some((candidate) => values.includes(candidate));
}

class Revision {
  @tracked value = 0;

  increment() {
    this.value++;
  }
}

class StateMachineSelector {
  #includeSilentUpdates;
  #machine;
  #machinePath;

  constructor(machine, machinePath, { includeSilentUpdates = false } = {}) {
    this.#machine = machine;
    this.#machinePath = machinePath;
    this.#includeSilentUpdates = includeSilentUpdates;
  }

  get current() {
    return this.#machine.stateValue(
      this.#machinePath,
      this.#includeSilentUpdates
    );
  }

  get lastProcessedMessage() {
    return this.#machine.lastProcessedMessage;
  }

  matches(state) {
    return this.#machine.matches(
      this.#resolveStatePath(state),
      this.#includeSilentUpdates,
      this.#machinePath
    );
  }

  toStrings() {
    return this.#machine.scopedStatePaths(
      this.#machinePath,
      this.#includeSilentUpdates
    );
  }

  send(message, context = {}) {
    const normalizedMessage =
      typeof message === "string"
        ? { ...context, type: message }
        : { ...context, ...message };

    if (!("machine" in normalizedMessage)) {
      normalizedMessage.machine = this.#machinePath;
    }

    return this.#machine.send(normalizedMessage);
  }

  sendUnscoped(message, context = {}) {
    return this.#machine.send(message, context);
  }

  subscribe(options) {
    return this.#machine.subscribe({
      ...options,
      state: asArray(options.state).map((state) =>
        this.#resolveStatePath(state)
      ),
    });
  }

  #resolveStatePath(state) {
    return this.#machine.resolveStatePath(this.#machinePath, state);
  }
}

export default class StateMachine {
  lastProcessedMessage = null;
  #activeStatePaths;
  #definition;
  #entryActions = [];
  #exitActions = [];
  #isDestroyed = false;
  #isProcessingQueue = false;
  #latestTimedSubscriptionTokens = new Map();
  #messageQueue = [];
  #publishedStatePaths;
  #revisionsByMachine = new Map();
  #scheduledAnimationFrames = new Set();
  #scheduledRunLoopTasks = new Set();
  #timedSubscriptions = [];
  #transitionActions = [];
  #allRevision = new Revision();
  #reactiveRevision = new Revision();

  constructor(machineDefinitions, { guards = {} } = {}) {
    this.#definition = new StateMachineDefinition(machineDefinitions, guards);
    this.#activeStatePaths = this.#definition.initialStatePaths();
    this.#publishedStatePaths = [...this.#activeStatePaths];
  }

  select(machinePath, options) {
    if (!this.#definition.hasMachine(machinePath)) {
      throw new Error(`Unknown state machine '${machinePath}'`);
    }

    return new StateMachineSelector(this, machinePath, options);
  }

  send(message, context = {}) {
    if (this.#isDestroyed) {
      return false;
    }

    const normalizedMessage = this.#normalizeMessage(message, context);
    this.#messageQueue.push(normalizedMessage);

    if (this.#isProcessingQueue) {
      return true;
    }

    return this.#processQueue();
  }

  subscribe({
    timing = TIMING.IMMEDIATE,
    state,
    transition = null,
    callback,
    guard = true,
    type = TYPE.ENTER,
  }) {
    if (this.#isDestroyed) {
      return () => {};
    }

    if (!Object.values(TIMING).includes(timing)) {
      throw new Error(`Unknown state effect timing '${timing}'`);
    }

    if (!Object.values(TYPE).includes(type)) {
      throw new Error(`Unknown state effect type '${type}'`);
    }

    if (type === TYPE.TRANSITION && timing !== TIMING.IMMEDIATE) {
      throw new Error("Transition effects must use immediate timing");
    }

    const subscription = {
      callback,
      guard,
      id: Symbol(),
      state: asArray(state),
      timing,
      transition:
        transition === null || transition === undefined
          ? null
          : asArray(transition),
      type,
    };

    if (timing !== TIMING.IMMEDIATE) {
      this.#timedSubscriptions.push(subscription);
    } else if (type === TYPE.EXIT) {
      this.#exitActions.push(subscription);
    } else if (type === TYPE.TRANSITION) {
      this.#transitionActions.push(subscription);
    } else {
      this.#entryActions.push(subscription);
    }

    return () => this.#unsubscribe(subscription.id);
  }

  matches(statePath, includeSilentUpdates = false, machinePath = null) {
    this.#consumeRevision(includeSilentUpdates, machinePath);
    return this.#definition.matches(this.#activeStatePaths, statePath);
  }

  stateValue(machinePath, includeSilentUpdates = false) {
    this.#consumeRevision(includeSilentUpdates, machinePath);
    return this.#definition.stateValue(this.#activeStatePaths, machinePath);
  }

  scopedStatePaths(machinePath, includeSilentUpdates = false) {
    this.#consumeRevision(includeSilentUpdates, machinePath);
    return this.#definition.scopedStatePaths(
      this.#activeStatePaths,
      machinePath
    );
  }

  toStrings(includeSilentUpdates = false) {
    this.#consumeRevision(includeSilentUpdates);
    return [...this.#activeStatePaths];
  }

  resolveStatePath(machinePath, state) {
    return this.#definition.resolveStatePath(machinePath, state);
  }

  cleanup() {
    if (this.#isDestroyed) {
      return;
    }

    this.#isDestroyed = true;

    for (const task of this.#scheduledRunLoopTasks) {
      cancel(task);
    }

    for (const frame of this.#scheduledAnimationFrames) {
      cancelAnimationFrame(frame);
    }

    this.#scheduledRunLoopTasks.clear();
    this.#scheduledAnimationFrames.clear();
    this.#latestTimedSubscriptionTokens.clear();
    this.#entryActions = [];
    this.#exitActions = [];
    this.#transitionActions = [];
    this.#timedSubscriptions = [];
    this.#messageQueue = [];
    this.#revisionsByMachine.clear();
  }

  #normalizeMessage(message, context) {
    const normalizedMessage =
      typeof message === "string"
        ? { ...context, type: message }
        : { ...context, ...message };

    if (typeof normalizedMessage.type !== "string") {
      throw new Error("State machine messages require a string type");
    }

    return normalizedMessage;
  }

  #processQueue() {
    let anyStateChanged = false;
    let reactiveStateChanged = false;
    const previousActiveStatePaths = this.#activeStatePaths;
    this.#isProcessingQueue = true;

    try {
      while (this.#messageQueue.length > 0) {
        const message = this.#messageQueue.shift();
        const result = this.#definition.transition(
          this.#activeStatePaths,
          message
        );

        if (!result.transitioned) {
          this.lastProcessedMessage = message;
          continue;
        }

        anyStateChanged = true;
        reactiveStateChanged ||= result.reactive;
        this.#activeStatePaths = result.nextStatePaths;

        this.#dispatchImmediateActions(result, message);
        this.lastProcessedMessage = message;
      }
    } catch (error) {
      this.#messageQueue = [];
      throw error;
    } finally {
      this.#isProcessingQueue = false;

      if (anyStateChanged) {
        this.#allRevision.increment();
        this.#incrementMachineRevisions(
          previousActiveStatePaths,
          this.#activeStatePaths,
          "all"
        );
      }

      if (reactiveStateChanged) {
        this.#reactiveRevision.increment();
        this.#incrementMachineRevisions(
          this.#publishedStatePaths,
          this.#activeStatePaths,
          "reactive"
        );
        this.#publishTimedSubscriptions();
      }
    }

    return anyStateChanged;
  }

  #dispatchImmediateActions(result, message) {
    this.#runActions(
      this.#exitActions,
      result.exitedStatePaths,
      result,
      message
    );
    this.#runActions(
      this.#transitionActions,
      result.exitedStatePaths,
      result,
      message
    );
    this.#runActions(
      this.#entryActions,
      result.enteredStatePaths,
      result,
      message
    );
  }

  #runActions(subscriptions, changedStatePaths, result, message) {
    for (const subscription of subscriptions) {
      if (
        !includesAny(changedStatePaths, subscription.state) ||
        !this.#matchesTransition(subscription, message) ||
        !this.#guardPasses(subscription, result.previousStatePaths, message)
      ) {
        continue;
      }

      subscription.callback(message);
    }
  }

  #dispatchTimedSubscriptions(result, message) {
    for (const subscription of this.#timedSubscriptions) {
      const entered = includesAny(result.enteredStatePaths, subscription.state);
      const exited = includesAny(result.exitedStatePaths, subscription.state);

      if (
        (subscription.type === TYPE.ENTER && exited) ||
        (subscription.type === TYPE.EXIT && entered)
      ) {
        this.#latestTimedSubscriptionTokens.delete(subscription.id);
      }

      const applies = subscription.type === TYPE.EXIT ? exited : entered;

      if (!applies || !this.#matchesTransition(subscription, message)) {
        continue;
      }

      const token = Symbol();
      this.#latestTimedSubscriptionTokens.set(subscription.id, token);

      const run = () => {
        const messageAtExecution = this.lastProcessedMessage;

        if (
          !this.#consumeTimedSubscriptionToken(subscription.id, token) ||
          !this.#timedStateStillApplies(subscription) ||
          !this.#guardPasses(
            subscription,
            result.previousStatePaths,
            messageAtExecution
          )
        ) {
          return;
        }

        subscription.callback(messageAtExecution);
      };

      if (subscription.timing === TIMING.AFTER_PAINT) {
        this.#scheduleAfterRender(() => this.#scheduleAnimationFrame(run));
      } else {
        this.#scheduleAfterRender(run);
      }
    }
  }

  #publishTimedSubscriptions() {
    const previousStatePaths = this.#publishedStatePaths;
    const previousStateSet = new Set(previousStatePaths);
    const activeStateSet = new Set(this.#activeStatePaths);
    const enteredStatePaths = this.#activeStatePaths.filter(
      (statePath) => !previousStateSet.has(statePath)
    );
    const exitedStatePaths = previousStatePaths.filter(
      (statePath) => !activeStateSet.has(statePath)
    );

    this.#publishedStatePaths = [...this.#activeStatePaths];
    this.#dispatchTimedSubscriptions(
      { enteredStatePaths, exitedStatePaths, previousStatePaths },
      this.lastProcessedMessage
    );
  }

  #timedStateStillApplies(subscription) {
    const matches = subscription.state.some((statePath) =>
      this.#definition.matches(this.#activeStatePaths, statePath)
    );

    return subscription.type === TYPE.EXIT ? !matches : matches;
  }

  #guardPasses(subscription, previousStatePaths, message) {
    return typeof subscription.guard === "function"
      ? subscription.guard(previousStatePaths, message)
      : subscription.guard;
  }

  #matchesTransition(subscription, message) {
    return (
      !subscription.transition || subscription.transition.includes(message.type)
    );
  }

  #consumeTimedSubscriptionToken(id, token) {
    if (this.#latestTimedSubscriptionTokens.get(id) !== token) {
      return false;
    }

    this.#latestTimedSubscriptionTokens.delete(id);
    return true;
  }

  #scheduleAfterRender(callback) {
    let task;
    task = schedule("afterRender", () => {
      this.#scheduledRunLoopTasks.delete(task);

      if (!this.#isDestroyed) {
        callback();
      }
    });
    this.#scheduledRunLoopTasks.add(task);
  }

  #scheduleAnimationFrame(callback) {
    const frame = requestAnimationFrame(() => {
      this.#scheduledAnimationFrames.delete(frame);

      if (!this.#isDestroyed) {
        callback();
      }
    });
    this.#scheduledAnimationFrames.add(frame);
  }

  #unsubscribe(id) {
    this.#latestTimedSubscriptionTokens.delete(id);
    this.#entryActions = this.#entryActions.filter(
      (subscription) => subscription.id !== id
    );
    this.#exitActions = this.#exitActions.filter(
      (subscription) => subscription.id !== id
    );
    this.#transitionActions = this.#transitionActions.filter(
      (subscription) => subscription.id !== id
    );
    this.#timedSubscriptions = this.#timedSubscriptions.filter(
      (subscription) => subscription.id !== id
    );
  }

  #consumeRevision(includeSilentUpdates, machinePath = null) {
    const revision = machinePath
      ? this.#machineRevision(machinePath, includeSilentUpdates)
      : includeSilentUpdates
        ? this.#allRevision
        : this.#reactiveRevision;

    revision.value;
  }

  #incrementMachineRevisions(previousStatePaths, nextStatePaths, type) {
    for (const [machinePath, revisions] of this.#revisionsByMachine) {
      const previousSelection = this.#definition.scopedStatePaths(
        previousStatePaths,
        machinePath
      );
      const nextSelection = this.#definition.scopedStatePaths(
        nextStatePaths,
        machinePath
      );

      if (
        previousSelection.length !== nextSelection.length ||
        previousSelection.some(
          (statePath, index) => statePath !== nextSelection[index]
        )
      ) {
        revisions[type].increment();
      }
    }
  }

  #machineRevision(machinePath, includeSilentUpdates) {
    if (!this.#revisionsByMachine.has(machinePath)) {
      this.#revisionsByMachine.set(machinePath, {
        all: new Revision(),
        reactive: new Revision(),
      });
    }

    const revisions = this.#revisionsByMachine.get(machinePath);
    return includeSilentUpdates ? revisions.all : revisions.reactive;
  }
}
