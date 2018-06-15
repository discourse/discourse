const {
  computed,
  getOwner,
  String: { dasherize }
} = Ember;

export default function(name) {
  return computed(function(defaultName) {
    return getOwner(this).lookup(`service:${name || dasherize(defaultName)}`);
  });
}
