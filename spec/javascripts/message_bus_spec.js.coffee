describe "Discourse.MessageBus", ->

  describe "Long polling", ->

    bus = Discourse.MessageBus
    bus.start()

    # PENDING: Fix to allow these to run in jasmine-guard
    
    #it "is able to get a response from the echo server", ->
    #  response = null
    #  bus.send("/echo", "hello world", (r) -> response = r)
    #  # give it some time to spin up
    #  waitsFor((-> response == "hello world"),"gotEcho",500)

    #it "should get responses from broadcast channel", ->
    #  response = null
    #  # note /message_bus/broadcast is dev only
    #  bus.subscribe("/animals", (r) -> response = r)
    #  $.ajax
    #    url: '/message-bus/broadcast'
    #    data: {channel: "/animals", data: "kitten"}
    #    cache: false
    #  waitsFor((-> response == "kitten"),"gotBroadcast", 500)
