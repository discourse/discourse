/**
 This mixin allows a class to return a singleton, as well as a method to quickly
 read/write attributes on the singleton.


 Example usage:

 ```javascript

 // Define your class and apply the Mixin
 User = EmberObject.extend({});
 User.reopenClass(Singleton);

 // Retrieve the current instance:
 var instance = User.current();

 ```

 Commonly you want to read or write a property on the singleton. There's a
 helper method which is a little nicer than `.current().get()`:

 ```javascript

 // Sets the age to 34
 User.currentProp('age', 34);

 console.log(User.currentProp('age')); // 34

 ```

 If you want to customize how the singleton is created, redefine the `createCurrent`
 method:

 ```javascript

 // Define your class and apply the Mixin
 Foot = EmberObject.extend({});
 Foot.reopenClass(Singleton, {
 createCurrent() {
 return Foot.create({ toes: 5 });
 }
 });

 console.log(Foot.currentProp('toes')); // 5

 ```
 **/
import Mixin from "@ember/object/mixin";
import deprecated from "discourse/lib/deprecated";

const Singleton = Mixin.create({
  init() {
    this._super(...arguments);

    deprecated(
      "Singleton mixin is deprecated. Use the singleton class decorator from discourse/lib/singleton instead.",
      {
        id: "discourse.singleton-mixin",
        since: "v3.4.0.beta4-dev",
      }
    );
  },

  current() {
    if (!this._current) {
      this._current = this.createCurrent();
    }
    return this._current;
  },

  /**
   How the singleton instance is created. This can be overridden
   with logic for creating (or even returning null) your instance.

   By default it just calls `create` with an empty object.
   **/
  createCurrent() {
    return this.create({});
  },

  // Returns OR sets a property on the singleton instance.
  currentProp(property, value) {
    let instance = this.current();
    if (!instance) {
      return;
    }

    if (typeof value !== "undefined") {
      instance.set(property, value);
      return value;
    } else {
      return instance.get(property);
    }
  },

  resetCurrent(val) {
    this._current = val;
    return val;
  },
});

export default Singleton;
