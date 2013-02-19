describe "Discourse.Onebox", ->

  beforeEach ->
    spyOn($, 'ajax').andCallThrough()

  it "Stops rapid calls with cache true", ->
    Discourse.Onebox.lookup('http://bla.com', true, (c) -> c)
    Discourse.Onebox.lookup('http://bla.com', true, (c) -> c)
    expect($.ajax.calls.length).toBe(1)

  it "Stops rapid calls with cache false", ->
    Discourse.Onebox.lookup('http://bla.com/a', false, (c) -> c)
    Discourse.Onebox.lookup('http://bla.com/a', false, (c) -> c)
    expect($.ajax.calls.length).toBe(1)
