/**
  A form to create an IP address that will be blocked or whitelisted.
  Example usage:

    {{screened-ip-address-form action="recordAdded"}}

  where action is a callback on the controller or route that will get called after
  the new record is successfully saved. It is called with the new ScreenedIpAddress record
  as an argument.
**/

import ScreenedIpAddress from "admin/models/screened-ip-address";
import computed from "ember-addons/ember-computed-decorators";
import { on } from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  classNames: ["screened-ip-address-form"],
  formSubmitted: false,
  actionName: "block",

  @computed
  adminWhitelistEnabled() {
    return Discourse.SiteSettings.use_admin_ip_whitelist;
  },

  @computed("adminWhitelistEnabled")
  actionNames(adminWhitelistEnabled) {
    if (adminWhitelistEnabled) {
      return [
        { id: "block", name: I18n.t("admin.logs.screened_ips.actions.block") },
        {
          id: "do_nothing",
          name: I18n.t("admin.logs.screened_ips.actions.do_nothing")
        },
        {
          id: "allow_admin",
          name: I18n.t("admin.logs.screened_ips.actions.allow_admin")
        }
      ];
    } else {
      return [
        { id: "block", name: I18n.t("admin.logs.screened_ips.actions.block") },
        {
          id: "do_nothing",
          name: I18n.t("admin.logs.screened_ips.actions.do_nothing")
        }
      ];
    }
  },

  actions: {
    submit() {
      if (!this.get("formSubmitted")) {
        this.set("formSubmitted", true);
        const screenedIpAddress = ScreenedIpAddress.create({
          ip_address: this.get("ip_address"),
          action_name: this.get("actionName")
        });
        screenedIpAddress
          .save()
          .then(result => {
            if (result.success) {
              this.setProperties({ ip_address: "", formSubmitted: false });
              this.sendAction(
                "action",
                ScreenedIpAddress.create(result.screened_ip_address)
              );
              Ember.run.schedule("afterRender", () =>
                this.$(".ip-address-input").focus()
              );
            } else {
              bootbox.alert(result.errors);
            }
          })
          .catch(e => {
            this.set("formSubmitted", false);
            const msg =
              e.jqXHR.responseJSON && e.jqXHR.responseJSON.errors
                ? I18n.t("generic_error_with_reason", {
                    error: e.jqXHR.responseJSON.errors.join(". ")
                  })
                : I18n.t("generic_error");
            bootbox.alert(msg, () => this.$(".ip-address-input").focus());
          });
      }
    }
  },

  @on("didInsertElement")
  _init() {
    Ember.run.schedule("afterRender", () => {
      this.$(".ip-address-input").keydown(e => {
        if (e.keyCode === 13) {
          this.send("submit");
        }
      });
    });
  }
});
