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

    // Chrome likes scrolling after HTML is set
    // This happens if you navigate back and forth a few times
    // Before removing this code confirm that this does not cause scrolling
    // 1. Sort by views
    // 2. Go to last post on one of the topics
    // 3. Hit back
    // 4. Go to last post on same topic
    // 5. Expand likes
    const scrollTop = $(window).scrollTop();
    $sel.html(buffer.join(''));
    $(window).scrollTop(scrollTop);
  },

  rerenderString() {
    Ember.run.once(this, '_rerenderString');
  }

});
