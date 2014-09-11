export default {
  name: "banner",
  after: "message-bus",

  initialize: function (container) {
    var banner = Em.Object.create(PreloadStore.get("banner")),
        site = container.lookup('site:main');

    site.set("banner", banner);

    if (!Discourse.MessageBus) { return; }

    Discourse.MessageBus.subscribe("/site/banner", function (banner) {
      site.set("banner", Em.Object.create(banner));
    });
  }
};
