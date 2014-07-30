module("Discourse.Onebox", {
  setup: function() {
    this.anchor = $("<a href='http://bla.com'></a>")[0];
  }
});

asyncTestDiscourse("Stops rapid calls with cache true", function() {
  sandbox.stub(Discourse, "ajax").returns(Ember.RSVP.resolve());
  Discourse.Onebox.load(this.anchor, true);
  Discourse.Onebox.load(this.anchor, true);

  start();
  ok(Discourse.ajax.calledOnce);
});

asyncTestDiscourse("Stops rapid calls with cache true", function() {
  sandbox.stub(Discourse, "ajax").returns(Ember.RSVP.resolve());
  Discourse.Onebox.load(this.anchor, false);
  Discourse.Onebox.load(this.anchor, false);

  start();
  ok(Discourse.ajax.calledOnce);
});
