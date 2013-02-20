/*global waitsFor:true expect:true describe:true beforeEach:true it:true */

(function() {

  describe("Discourse.KeyValueStore", function() {
    return describe("Setting values", function() {
      var store;
      store = Discourse.KeyValueStore;
      store.init("test");
      it("able to get the value back from the store", function() {
        store.set({
          key: "bob",
          value: "uncle"
        });
        return expect(store.get("bob")).toBe("uncle");
      });
      return it("able to nuke the store", function() {
        store.set({
          key: "bob1",
          value: "uncle"
        });
        store.abandonLocal();
        localStorage.a = 1;
        expect(store.get("bob1")).toBe(void 0);
        return expect(localStorage.a).toBe("1");
      });
    });
  });

}).call(this);
