export default Discourse.Route.extend({

  beforeModel: function() {
    this.replaceWith('userActivity');
  }

});
