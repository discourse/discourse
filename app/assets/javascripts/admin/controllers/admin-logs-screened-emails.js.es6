export default Ember.ArrayController.extend(Discourse.Presence, {
  loading: false,

  actions: {
    clearBlock: function(row){
      row.clearBlock().then(function(){
        // feeling lazy
        window.location.reload();
      });
    }
  },

  show: function() {
    var self = this;
    this.set('loading', true);
    Discourse.ScreenedEmail.findAll().then(function(result) {
      self.set('model', result);
      self.set('loading', false);
    });
  }
});
