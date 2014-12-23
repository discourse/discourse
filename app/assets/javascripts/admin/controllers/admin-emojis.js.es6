export default Ember.ArrayController.extend({
  sortProperties: ["name"],

  actions: {
    emojiUploaded: function (emoji) {
      this.pushObject(emoji);
    },

    destroy: function(emoji) {
      var self = this;
      return bootbox.confirm(I18n.t("admin.emoji.delete_confirm", { name: emoji.name }), I18n.t("no_value"), I18n.t("yes_value"), function (destroy) {
        if (destroy) {
          return Discourse.ajax("/admin/customize/emojis/" + emoji.name, { type: "DELETE" }).then(function() {
            self.removeObject(emoji);
          });
        }
      });
    }
  }
});
