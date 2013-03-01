/*global waitsFor:true expect:true describe:true beforeEach:true it:true spyOn:true */

describe("Discourse.Onebox", function() {

  beforeEach(function() {
    spyOn(jQuery, 'ajax').andCallThrough();
  });

  it("Stops rapid calls with cache true", function() {
    Discourse.Onebox.lookup('http://bla.com', true, function(c) { return c; });
    Discourse.Onebox.lookup('http://bla.com', true, function(c) { return c; });
    expect(jQuery.ajax.calls.length).toBe(1);
  });

  it("Stops rapid calls with cache false", function() {
    Discourse.Onebox.lookup('http://bla.com/a', false, function(c) { return c; });
    Discourse.Onebox.lookup('http://bla.com/a', false, function(c) { return c; });
    expect(jQuery.ajax.calls.length).toBe(1);
  });

});
