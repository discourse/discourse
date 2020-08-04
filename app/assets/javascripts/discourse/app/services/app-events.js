import deprecated from "discourse-common/lib/deprecated";
import Evented from "@ember/object/evented";
import Service from "@ember/service";

let _events = {};

export function clearAppEventsCache(container) {
  if (container) {
    const appEvents = container.lookup("service:app-events");
    Object.keys(_events).forEach(eventKey => {
      const event = _events[eventKey];
      event.forEach(listener => {
        if (appEvents.has(eventKey)) {
          appEvents.off(eventKey, listener.target, listener.fn);
        }
      });
    });
  }

  _events = {};
}

export default Service.extend(Evented, {
  on() {
    if (arguments.length === 2) {
      let [name, fn] = arguments;
      let target = {};
      _events[name] = _events[name] || [];
      _events[name].push({ target, fn });

      this._super(name, target, fn);
    } else if (arguments.length === 3) {
      let [name, target, fn] = arguments;
      _events[name] = _events[name] || [];
      _events[name].push({ target, fn });

      this._super(...arguments);
    }
    return this;
  },

  off() {
    let name = arguments[0];
    let fn = arguments[2];

    if (_events[name]) {
      if (arguments.length === 1) {
        deprecated(
          "Removing all event listeners at once is deprecated, please remove each listener individually."
        );

        _events[name].forEach(ref => {
          this._super(name, ref.target, ref.fn);
        });
        delete _events[name];
      } else if (arguments.length === 3) {
        this._super(...arguments);

        _events[name] = _events[name].filter(e => e.fn !== fn);
        if (_events[name].length === 0) delete _events[name];
      }
    }

    return this;
  }
});
