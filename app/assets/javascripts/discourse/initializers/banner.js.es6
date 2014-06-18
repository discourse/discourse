export default {
  name: "banner",
  after: "message-bus",

  initialize: function () {
    var banner = Em.Object.create(PreloadStore.get("banner"));
    Discourse.set("banner", banner);

    if (!Discourse.MessageBus) { return; }

    Discourse.MessageBus.subscribe("/site/banner", function (banner) {
      Discourse.set("banner", Em.Object.create(banner));
    });
  }
};
