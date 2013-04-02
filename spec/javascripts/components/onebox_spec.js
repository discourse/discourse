/*global waitsFor:true expect:true describe:true beforeEach:true it:true spyOn:true */

describe("Discourse.Onebox", function() {

  var anchor;

  beforeEach(function() {
    spyOn(Discourse, 'ajax').andCallThrough();
    anchor = $("<a href='http://bla.com'></a>")[0];
  });

  it("Stops rapid calls with cache true", function() {
    Discourse.Onebox.load(anchor, true);
    Discourse.Onebox.load(anchor, true);
    expect(Discourse.ajax.calls.length).toBe(1);
  });

  it("Stops rapid calls with cache false", function() {
    Discourse.Onebox.load(anchor, false);
    Discourse.Onebox.load(anchor, false);
    expect(Discourse.ajax.calls.length).toBe(1);
  });

});
