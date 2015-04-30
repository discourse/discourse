export default Ember.Mixin.create({

  _watchProps: function() {
    const args = this.get('rerenderTriggers');
    if (!Ember.isNone(args)) {
      args.forEach(k => this.addObserver(k, this.rerenderString));
    }
  }.on('init'),

  render(buffer) {
    this.renderString(buffer);
  },

  renderString(buffer){
    const template = Discourse.__container__.lookup('template:' + this.rawTemplate);
    if (template) {
      buffer.push(template(this));
    }
  },

  _rerenderString() {
    const $sel = this.$();
    if (!$sel) { return; }

    const buffer = [];
    this.renderString(buffer);

    $sel.html(buffer.join(''));
  },

  rerenderString() {
    Ember.run.once(this, '_rerenderString');
  }

});
