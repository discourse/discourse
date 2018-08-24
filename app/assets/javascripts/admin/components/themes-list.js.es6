export default Ember.Component.extend({
  classNames: ["themes-list"],
  hasThemes: Ember.computed.gt("themes.length", 0)
});
