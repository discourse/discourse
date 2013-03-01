/*global waitsFor:true expect:true describe:true beforeEach:true it:true */

describe("Discourse.KeyValueStore", function() {

  describe("Setting values", function() {
    var store = Discourse.KeyValueStore;
    store.init("test");

    it("is able to get the value back from the store", function() {
      store.set({ key: "bob", value: "uncle" });
      expect(store.get("bob")).toBe("uncle");
    });

    it("is able to nuke the store", function() {
      store.set({ key: "bob1", value: "uncle" });
      store.abandonLocal();
      localStorage.a = 1;
      expect(store.get("bob1")).toBe(void 0);
      expect(localStorage.a).toBe("1");
    });

  });

});
