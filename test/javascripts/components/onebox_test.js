module("Discourse.Onebox", {
  setup: function() {
    this.anchor = $("<a href='http://bla.com'></a>")[0];
  }
});

test("Stops rapid calls with cache true", function() {
  this.stub(Discourse, "ajax").returns(resolvingPromise);

  Discourse.Onebox.load(this.anchor, true);
  Discourse.Onebox.load(this.anchor, true);
  ok(Discourse.ajax.calledOnce);
});

test("Stops rapid calls with cache false", function() {
  this.stub(Discourse, "ajax").returns(resolvingPromise);
  Discourse.Onebox.load(this.anchor, false);
  Discourse.Onebox.load(this.anchor, false);
  ok(Discourse.ajax.calledOnce);
});