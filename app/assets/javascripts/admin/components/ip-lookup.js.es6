
export default Ember.Component.extend({
  classNames: ["ip-lookup"],

  city: function () {
    return [
      this.get("location.city"),
      this.get("location.region"),
      this.get("location.country")
    ].filter(Boolean).join(", ");
  }.property("location.{city,region,country}"),

  otherAccountsToDelete: function() {
    // can only delete up to 50 accounts at a time
    var total = Math.min(50, this.get("totalOthersWithSameIP") || 0);
    var visible = Math.min(50, this.get("other_accounts.length") || 0);
    return Math.max(visible, total);
  }.property("other_accounts", "totalOthersWithSameIP"),

  actions: {
    lookup: function () {
      var self = this;
      this.set("show", true);

      if (!this.get("location")) {
        Discourse.ajax("/admin/users/ip-info", {
          data: { ip: this.get("ip") }
        }).then(function (location) {
          self.set("location", Em.Object.create(location));
        });
      }

      if (!this.get("other_accounts")) {
        this.set("otherAccountsLoading", true);

        var data = {
          "ip": this.get("ip"),
          "exclude": this.get("userId"),
          "order": "trust_level DESC"
        };

        Discourse.ajax("/admin/users/total-others-with-same-ip", { data }).then(function (result) {
          self.set("totalOthersWithSameIP", result.total);
        });

        const AdminUser = require('admin/models/admin-user').default;
        AdminUser.findAll("active", data).then(function (users) {
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
          self.setProperties({
            other_accounts: null,
            otherAccountsLoading: true,
            totalOthersWithSameIP: null
          });

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
