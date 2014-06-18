/**
  Subscribe to "asset-version" change events via the Message Bus
**/
export default {
  name: "asset-version",
  after: "message-bus",

  initialize: function () {
    if (!Discourse.MessageBus) { return; }

    Discourse.MessageBus.subscribe("/global/asset-version", function (version) {
      Discourse.set("assetVersion", version);

      if (Discourse.get("requiresRefresh")) {
        // since we can do this transparently for people browsing the forum
        //  hold back the message a couple of hours
        setTimeout(function () {
          bootbox.confirm(I18n.lookup("assets_changed_confirm"), function (result) {
            if (result) { document.location.reload(); }
          });
        }, 1000 * 60 * 120);
      }

    });
  }
};
