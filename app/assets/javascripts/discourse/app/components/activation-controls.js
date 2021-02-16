import Component from "@ember/component";
import { or } from "@ember/object/computed";

export default Component.extend({
  classNames: "activation-controls",
  canEditEmail: or(
    "siteSettings.enable_local_logins",
    "siteSettings.email_editable"
  ),
});
