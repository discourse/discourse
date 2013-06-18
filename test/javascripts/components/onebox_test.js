/*global module:true test:true ok:true visit:true equal:true exists:true count:true equal:true present:true md5:true resolvingPromise:true */

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