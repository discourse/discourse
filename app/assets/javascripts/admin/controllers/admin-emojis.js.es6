export default Ember.ArrayController.extend({
  sortProperties: ["name"],

  actions: {
    emojiUploaded(emoji) {
      emoji.url += "?t=" + new Date().getTime();
      this.pushObject(Ember.Object.create(emoji));
    },

    destroy(emoji) {
      const self = this;
      return bootbox.confirm(
        I18n.t("admin.emoji.delete_confirm", { name: emoji.get("name") }),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        function(destroy) {
          if (destroy) {
            return Discourse.ajax("/admin/customize/emojis/" + emoji.get("name"), { type: "DELETE" }).then(function() {
              self.removeObject(emoji);
            });
          }
        }
      );
    }
  }
});
