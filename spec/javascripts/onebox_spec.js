/*global waitsFor:true expect:true describe:true beforeEach:true it:true spyOn:true */
(function() {

  describe("Discourse.Onebox", function() {
    beforeEach(function() {
      return spyOn(jQuery, 'ajax').andCallThrough();
    });
    it("Stops rapid calls with cache true", function() {
      Discourse.Onebox.lookup('http://bla.com', true, function(c) {
        return c;
      });
      Discourse.Onebox.lookup('http://bla.com', true, function(c) {
        return c;
      });
      return expect(jQuery.ajax.calls.length).toBe(1);
    });
    return it("Stops rapid calls with cache false", function() {
      Discourse.Onebox.lookup('http://bla.com/a', false, function(c) {
        return c;
      });
      Discourse.Onebox.lookup('http://bla.com/a', false, function(c) {
        return c;
      });
      return expect(jQuery.ajax.calls.length).toBe(1);
    });
  });

}).call(this);
