export default Em.Route.extend({

  beforeModel: function() {
    return this.replaceWith('userActivity');
  }

});
