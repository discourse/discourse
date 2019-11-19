import deprecated from "discourse-common/lib/deprecated";
import Service from "@ember/service";

export default Service.extend(Ember.Evented, {
  _events: {},

  on() {
    if (arguments.length === 2) {
      let [name, fn] = arguments;
      let target = {};
      this._events[name] = this._events[name] || [];
      this._events[name].push({ target, fn });

      this._super(name, target, fn);
    } else if (arguments.length === 3) {
      let [name, target, fn] = arguments;
      this._events[name] = this._events[name] || [];
      this._events[name].push({ target, fn });

      this._super(...arguments);
    }
    return this;
  },

  off() {
    let name = arguments[0];
    let fn = arguments[2];

    if (this._events[name]) {
      if (arguments.length === 1) {
        deprecated(
          "Removing all event listeners at once is deprecated, please remove each listener individually."
        );

        this._events[name].forEach(ref => {
          this._super(name, ref.target, ref.fn);
        });
        delete this._events[name];
      } else if (arguments.length === 3) {
        this._super(...arguments);

        this._events[name] = this._events[name].filter(e => e.fn !== fn);
        if (this._events[name].length === 0) delete this._events[name];
      }
    }

    return this;
  }
});
