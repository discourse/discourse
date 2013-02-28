/*global waitsFor:true expect:true describe:true beforeEach:true it:true */

  describe("Discourse.MessageBus", function() {

    describe("Long polling", function() {
      var bus = Discourse.MessageBus;
      bus.start();
    });

  });
