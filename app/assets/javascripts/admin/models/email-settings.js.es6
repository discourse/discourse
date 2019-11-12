import { ajax } from "discourse/lib/ajax";
import EmberObject from "@ember/object";

const EmailSettings = EmberObject.extend({});

EmailSettings.reopenClass({
  find: function() {
    return ajax("/admin/email.json").then(function(settings) {
      return EmailSettings.create(settings);
    });
  }
});

export default EmailSettings;
