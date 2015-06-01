/**
  This mixin provides `blank` and `present` to determine whether properties are
  there, accounting for more cases than just null and undefined.
**/
export default Ember.Mixin.create({

  /**
    Returns whether a property is blank. It considers empty arrays, string, objects, undefined and null
    to be blank, otherwise true.
  */
  blank(name) {
    return Ember.isEmpty(this[name] || this.get(name));
  },

  // Returns whether a property is present. A present property is the opposite of a `blank` one.
  present(name) {
    return !this.blank(name);
  }

});
