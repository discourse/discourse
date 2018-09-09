import { emojiUrlFor } from "discourse/lib/text";

const externalResources = [
  {
    key: "admin.customize.theme.beginners_guide_title",
    link: "https://meta.discourse.org/t/91966",
    icon: "book"
  },
  {
    key: "admin.customize.theme.developers_guide_title",
    link: "https://meta.discourse.org/t/93648",
    icon: "book"
  },
  {
    key: "admin.customize.theme.browse_themes",
    link: "https://meta.discourse.org/c/theme",
    icon: "paint-brush"
  }
];

export default Ember.Route.extend({
  setupController(controller) {
    this._super(...arguments);
    this.controllerFor("adminCustomizeThemes").set("editingTheme", false);
    controller.setProperties({
      externalResources,
      womanArtistEmojiURL: emojiUrlFor("woman_artist:t5")
    });
  }
});
