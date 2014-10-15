export default Discourse.Route.extend({

  beforeModel: function() {
    return this.replaceWith('userActivity');
  }

});
