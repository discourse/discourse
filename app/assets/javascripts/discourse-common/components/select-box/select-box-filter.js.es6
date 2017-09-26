export default Ember.Component.extend({
  layoutName: "discourse-common/templates/components/select-box/select-box-filter",

  classNames: "select-box-filter",

  classNameBindings: ["focused:is-focused"]
});
