export default Ember.Mixin.create({

  _watchProps: function() {
    var args = this.get('rerenderTriggers');
    if (!Ember.isNone(args)) {
      var self = this;
      args.forEach(function(k) {
        self.addObserver(k, self.rerenderString);
      });
    }
  }.on('init'),

  render: function(buffer) {
    this.renderString(buffer);
  },

  renderString: function(buffer){
    var template = Discourse.__container__.lookup('template:' + this.rawTemplate);
    if (template) {
      buffer.push(template(this));
    }
  },

  _rerenderString: function() {
    var buffer = [];
    this.renderString(buffer);
    this.$().html(buffer.join(''));
  },

  rerenderString: function() {
    Ember.run.once(this, '_rerenderString');
  }

});
