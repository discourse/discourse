/*global waitsFor:true expect:true describe:true beforeEach:true it:true */

  describe("Discourse.MessageBus", function() {
    return describe("Long polling", function() {
      var bus;
      bus = Discourse.MessageBus;
      return bus.start();
    });
  });


