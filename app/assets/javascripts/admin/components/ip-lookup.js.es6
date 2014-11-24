export default Ember.Component.extend({
  classNames: ["ip-lookup"],

  city: function () {
    return [
      this.get("location.city"),
      this.get("location.region"),
      this.get("location.country")
    ].filter(Boolean).join(", ");
  }.property("location.{city,region,country}"),

  actions: {
    lookup: function () {
      var self = this;
      this.set("show", true);

      if (!this.get("location")) {
        Discourse.ajax("/admin/users/ip-info.json", {
          data: { ip: this.get("ip") }
        }).then(function (location) {
          self.set("location", Em.Object.create(location));
        });
      }

      if (!this.get("other_accounts")) {
        this.set("otherAccountsLoading", true);
        Discourse.AdminUser.findAll("active", {
          "ip": this.get("ip"),
          "exclude": this.get("userId"),
          "order": "trust_level DESC"
        }).then(function (users) {
          self.setProperties({
            other_accounts: users,
            otherAccountsLoading: false,
          });
        });
      }
    },

    hide: function () {
      this.set("show", false);
    },

    deleteOtherAccounts: function() {
      var self = this;
      bootbox.confirm(I18n.t("ip_lookup.confirm_delete_other_accounts"), I18n.t("no_value"), I18n.t("yes_value"), function (confirmed) {
        if (confirmed) {
          self.setProperties({ other_accounts: null, otherAccountsLoading: true });
          Discourse.ajax("/admin/users/delete-others-with-same-ip.json", {
            type: "DELETE",
            data: {
              "ip": self.get("ip"),
              "exclude": self.get("userId"),
              "order": "trust_level DESC"
            }
          }).then(function() {
            self.send("lookup");
          });
        }
      });
    }
  }
});
