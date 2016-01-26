import Category from 'discourse/models/category';

export default Discourse.Route.extend({
  model: function(params) {
    return Category.findById(params.id);
  },

  redirect: function(model) {
    this.transitionTo(`/c/${Category.slugFor(model)}`);
  }
});
