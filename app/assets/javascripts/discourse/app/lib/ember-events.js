import { EventDispatcher } from "@ember/-internals/views";
import Component from "@ember/component";
import EmberObject from "@ember/object";
import { actionModifier } from "./ember-action-modifier";

/**
 * Classic Ember components (i.e. "@ember/component") rely upon "event
 * delegation" to listen for events at the application root and then dispatch
 * those events to any event handlers defined on individual Classic components.
 * This coordination is handled by Ember's EventDispatcher.
 *
 * In contrast, Glimmer components (i.e. "@glimmer/component") expect event
 * listeners to be added to elements using modifiers (such as `{{on "click"}}`).
 * These event listeners are added directly to DOM elements using
 * `addEventListener`. There is no need for an event dispatcher.
 *
 * Issues may arise when using Classic and Glimmer components together, since it
 * requires reconciling the two event handling approaches. For instance, event
 * propagation may not work as expected when a Classic component is nested
 * inside a Glimmer component.
 *
 * `normalizeEmberEventHandling` helps an application standardize upon the
 * Glimmer event handling approach by eliminating usage of event delegation and
 * instead rewiring Classic components to directly use `addEventListener`.
 *
 * Specifically, it performs the following:
 *
 * - Invokes `eliminateClassicEventDelegation()` to remove all events associated
 *   with Ember's EventDispatcher to reduce its runtime overhead and ensure that
 *   it is effectively not in use.
 *
 * - Invokes `rewireClassicComponentEvents(app)` to rewire each Classic
 *   component to add its own event listeners for standard event handlers (e.g.
 *   `click`, `mouseDown`, `submit`, etc.).
 *
 * - Configures an instance initializer that invokes
 *   `rewireActionModifier(appInstance)` to redefine the `action` modifier with
 *   a substitute that uses `addEventListener`.
 *
 * @param {Application} app
 */
export function normalizeEmberEventHandling(app) {
  eliminateClassicEventDelegation();
  rewireClassicComponentEvents(app);
  app.instanceInitializer({
    name: "rewire-action-modifier",
    initialize: (appInstance) => rewireActionModifier(appInstance),
  });
}

/**
 * Remove all events registered with Ember's EventDispatcher to reduce its
 * runtime overhead.
 */
function eliminateClassicEventDelegation() {
  EventDispatcher.reopen({
    events: {},
  });
}

/**
 * Standard Ember event handlers, keyed by matching DOM events.
 *
 * Source: https://github.com/emberjs/ember.js/blob/master/packages/@ember/-internals/views/lib/system/event_dispatcher.ts#L64-L89
 *
 * @type {Record<string, string>}
 */
const EVENTS = {
  touchstart: "touchStart",
  touchmove: "touchMove",
  touchend: "touchEnd",
  touchcancel: "touchCancel",
  keydown: "keyDown",
  keyup: "keyUp",
  keypress: "keyPress",
  mousedown: "mouseDown",
  mouseup: "mouseUp",
  contextmenu: "contextMenu",
  click: "click",
  dblclick: "doubleClick",
  focusin: "focusIn",
  focusout: "focusOut",
  submit: "submit",
  input: "input",
  change: "change",
  dragstart: "dragStart",
  drag: "drag",
  dragenter: "dragEnter",
  dragleave: "dragLeave",
  dragover: "dragOver",
  drop: "drop",
  dragend: "dragEnd",
};

/**
 * @type {WeakMap<object, { event: string; listener: () => {} }[]>}
 */
const EVENT_LISTENERS = new WeakMap();

const INTERNAL = Symbol("INTERNAL");

/**
 * Rewires classic component event handling to use `addEventListener` directly
 * on inserted elements, instead of relying upon classic event delegation.
 *
 * This maximizes compatibility with glimmer components and event listeners
 * added via the `on` modifier. In particular, using `addEventListener`
 * consistently everywhere ensures that event propagation works as expected
 * between parent and child elements.
 *
 * @param {Application} app
 */
function rewireClassicComponentEvents(app) {
  const allEvents = { ...EVENTS };

  if (app.customEvents) {
    for (const [event, methodName] of Object.entries(app.customEvents)) {
      allEvents[event] = methodName;
    }
  }

  const allEventMethods = {};
  for (const [event, methodName] of Object.entries(allEvents)) {
    allEventMethods[methodName] = event;
  }

  // Avoid Component.reopen to stop `ember.component.reopen` deprecation warning
  EmberObject.reopen.call(Component, {
    /**
     * @param {string | typeof INTERNAL} name
     * @param {unknown[]} args
     */
    _trigger(name, ...args) {
      if (name === INTERNAL) {
        if (this.element) {
          return this._super.call(this, ...args);
        }
      } else if (name.toLowerCase() in allEvents) {
        return;
      } else {
        return this._super.call(this, name, ...args);
      }
    },

    didInsertElement() {
      this._super(...arguments);
      setupComponentEventListeners(this, allEventMethods);
    },

    willDestroyElement() {
      teardownComponentEventListeners(this);
      this._super(...arguments);
    },
  });
}

/**
 * Rewires the `action` modifier to use `addEventListener` directly instead of
 * relying upon classic event delegation.
 *
 * This relies upon a deep override of Ember's rendering internals. If possible,
 * consider eliminating usage of `action` as a modifier instead.
 *
 * @param {ApplicationInstance} appInstance
 */
function rewireActionModifier(appInstance) {
  // This is a deep runtime override, since neither the runtime resolver nor the
  // built-in `action` modifier seem to be available otherwise.
  //
  // TODO: Investigate if a cleaner override is possible.
  const renderer = appInstance.lookup("renderer:-dom");
  const lookupModifier = renderer._runtimeResolver.lookupModifier;
  renderer._runtimeResolver.lookupModifier = (name, owner) => {
    if (name === "action") {
      return actionModifier;
    } else {
      return lookupModifier(name, owner);
    }
  };
}

function setupComponentEventListeners(component, allEventMethods) {
  let eventListeners;
  const { element } = component;

  for (const method of Object.keys(allEventMethods)) {
    if (component.has(method)) {
      const event = allEventMethods[method];

      if (eventListeners === undefined) {
        eventListeners = EVENT_LISTENERS.get(component);
        if (eventListeners === undefined) {
          eventListeners = [];
          EVENT_LISTENERS.set(component, eventListeners);
        }
      }

      const listener = (e) => {
        const ret = component.trigger.call(component, INTERNAL, method, e);
        // If an event handler returns `false`, assume the intent is to stop
        // propagation and default event handling, as per the behavior
        // encoded in Ember's `EventDispatcher`.
        //
        // See: https://github.com/emberjs/ember.js/blob/7d9095f38911d30aebb0e67ceec13e4a9818088b/packages/%40ember/-internals/views/lib/system/event_dispatcher.ts#L331-L337
        if (ret === false) {
          e.preventDefault();
          e.stopPropagation();
        }
        return ret;
      };

      element.addEventListener(event, listener);
      eventListeners.push({ event, listener });
    }
  }
}

function teardownComponentEventListeners(component) {
  const eventListeners = EVENT_LISTENERS.get(component);
  if (eventListeners?.length > 0) {
    const { element } = component;
    if (element) {
      for (const { event, listener } of eventListeners) {
        element.removeEventListener(event, listener);
      }
    }
    EVENT_LISTENERS.delete(component);
  }
}
