describe "Discourse.KeyValueStore", ->

  describe "Setting values", ->

    store = Discourse.KeyValueStore
    store.init("test")
      
    it "able to get the value back from the store", ->
      store.set(key: "bob", value: "uncle")
      expect(store.get("bob")).toBe("uncle")

    it "able to nuke the store", ->
      store.set(key: "bob1", value: "uncle")
      store.abandonLocal()
      localStorage["a"] = 1
      expect(store.get("bob1")).toBe(undefined)
      expect(localStorage["a"]).toBe("1")
