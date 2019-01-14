import { ajax } from "discourse/lib/ajax";
import AdminUser from "admin/models/admin-user";
import copyText from "discourse/lib/copy-text";

export default Ember.Component.extend({
  classNames: ["ip-lookup"],

  otherAccountsToDelete: function() {
    // can only delete up to 50 accounts at a time
    var total = Math.min(50, this.get("totalOthersWithSameIP") || 0);
    var visible = Math.min(50, this.get("other_accounts.length") || 0);
    return Math.max(visible, total);
  }.property("other_accounts", "totalOthersWithSameIP"),

  actions: {
    lookup: function() {
      var self = this;
      this.set("show", true);

      if (!this.get("location")) {
        ajax("/admin/users/ip-info", {
          data: { ip: this.get("ip") }
        }).then(function(location) {
          self.set("location", Ember.Object.create(location));
        });
      }

      if (!this.get("other_accounts")) {
        this.set("otherAccountsLoading", true);

        var data = {
          ip: this.get("ip"),
          exclude: this.get("userId"),
          order: "trust_level DESC"
        };

        ajax("/admin/users/total-others-with-same-ip", { data }).then(function(
          result
        ) {
          self.set("totalOthersWithSameIP", result.total);
        });

        AdminUser.findAll("active", data).then(function(users) {
          self.setProperties({
            other_accounts: users,
            otherAccountsLoading: false
          });
        });
      }
    },

    hide: function() {
      this.set("show", false);
    },

    copy: function() {
      let text = `IP: ${this.get("ip")}\n`;
      const location = this.get("location");
      if (location) {
        if (location.hostname) {
          text += `${I18n.t("ip_lookup.hostname")}: ${location.hostname}\n`;
        }

        text += I18n.t("ip_lookup.location");
        if (location.location) {
          text += `: ${location.location}\n`;
        } else {
          text += `: ${I18n.t("ip_lookup.location_not_found")}\n`;
        }

        if (location.organization) {
          text += I18n.t("ip_lookup.organisation");
          text += `: ${location.organization}\n`;
        }
      }
      const copyRange = $('<p id="copy-range"></p>');
      copyRange.html(text.trim().replace(/\n/g, "<br>"));
      $(document.body).append(copyRange);
      if (copyText(text, copyRange[0])) {
        this.set("copied", true);
        Ember.run.later(() => this.set("copied", false), 2000);
      }
      copyRange.remove();
    },

    deleteOtherAccounts: function() {
      var self = this;
      bootbox.confirm(
        I18n.t("ip_lookup.confirm_delete_other_accounts"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        function(confirmed) {
          if (confirmed) {
            self.setProperties({
              other_accounts: null,
              otherAccountsLoading: true,
              totalOthersWithSameIP: null
            });

            ajax("/admin/users/delete-others-with-same-ip.json", {
              type: "DELETE",
              data: {
                ip: self.get("ip"),
                exclude: self.get("userId"),
                order: "trust_level DESC"
              }
            }).then(function() {
              self.send("lookup");
            });
          }
        }
      );
    }
  }
});
