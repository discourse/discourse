export default Ember.Mixin.create({
  _castInteger(value) {
    if (this.get("castInteger") === true && Ember.isPresent(value)) {
      return parseInt(value, 10);
    }

    return Ember.isNone(value) ? value : value.toString();
  }
});
