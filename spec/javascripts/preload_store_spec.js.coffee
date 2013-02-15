describe "PreloadStore", ->

  beforeEach ->
    PreloadStore.store('bane', 'evil')

  describe "contains", ->

    it "returns false for a key that doesn't exist", ->
      expect(PreloadStore.contains('joker')).toBe(false)

    it "returns true for a stored key", ->
      expect(PreloadStore.contains('bane')).toBe(true)

  describe 'getStatic', ->

    it "returns undefined if the key doesn't exist", ->
      expect(PreloadStore.getStatic('joker')).toBe(undefined)

    it "returns the the key if it exists", ->
      expect(PreloadStore.getStatic('bane')).toBe('evil')

    it "removes the key after being called", ->
      PreloadStore.getStatic('bane')
      expect(PreloadStore.getStatic('bane')).toBe(undefined)


  describe 'get', ->


    it "returns a promise that resolves to undefined", ->
      done = storeResult = null
      PreloadStore.get('joker').then (result) ->
        done = true
        storeResult = result
      waitsFor (-> return done), "Promise never resolved", 1000
      runs -> expect(storeResult).toBe(undefined)

    it "returns a promise that resolves to the result of the finder", ->
      done = storeResult = null
      finder = -> 'evil'       
      PreloadStore.get('joker', finder).then (result) ->
        done = true
        storeResult = result
      waitsFor (-> return done), "Promise never resolved", 1000
      runs -> expect(storeResult).toBe('evil')    

    it "returns a promise that resolves to the result of the finder's promise", ->
      done = storeResult = null
      finder = -> 
        promise = new RSVP.Promise
        promise.resolve('evil')
        promise
        
      PreloadStore.get('joker', finder).then (result) ->
        done = true
        storeResult = result
      waitsFor (-> return done), "Promise never resolved", 1000
      runs -> expect(storeResult).toBe('evil')

    it "returns a promise that resolves to the result of the finder's rejected promise", ->
      done = storeResult = null
      finder = -> 
        promise = new RSVP.Promise
        promise.reject('evil')
        promise
        
      PreloadStore.get('joker', finder).then null, (rejectedResult) ->
        done = true
        storeResult = rejectedResult

      waitsFor (-> return done), "Promise never rejected", 1000
      runs -> expect(storeResult).toBe('evil')


    it "returns a promise that resolves to 'evil'", ->
      done = storeResult = null
      PreloadStore.get('bane').then (result) ->
        done = true
        storeResult = result
      waitsFor (-> return done), "Promise never resolved", 1000
      runs -> expect(storeResult).toBe('evil')
