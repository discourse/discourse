/**
  Initialize the message bus to receive messages.
**/
Discourse.addInitializer(function() {

  // We don't use the message bus in testing
  if (Discourse.testing) { return; }

  Discourse.MessageBus.alwaysLongPoll = Discourse.Environment === "development";
  Discourse.MessageBus.start();
  Discourse.MessageBus.subscribe("/global/asset-version", function(version){
    Discourse.set("assetVersion",version);

    if(Discourse.get("requiresRefresh")) {
      // since we can do this transparently for people browsing the forum
      //  hold back the message a couple of hours
      setTimeout(function() {
        bootbox.confirm(I18n.lookup("assets_changed_confirm"), function(){
          document.location.reload();
        });
      }, 1000 * 60 * 120);
    }

  });
  Discourse.KeyValueStore.init("discourse_", Discourse.MessageBus);
}, true);
