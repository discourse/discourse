/**
  Initialize the message bus to receive messages.
**/
Discourse.addInitializer(function() {
  Discourse.MessageBus.alwaysLongPoll = Discourse.Environment === "development";
  Discourse.MessageBus.start();
  Discourse.MessageBus.subscribe("/global/asset-version", function(version){
    Discourse.set("assetVersion",version);
  });
  Discourse.KeyValueStore.init("discourse_", Discourse.MessageBus);
}, true);
