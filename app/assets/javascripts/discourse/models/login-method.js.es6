import EmberObject from "@ember/object";
import computed from "ember-addons/ember-computed-decorators";
import { updateCsrfToken } from "discourse/lib/ajax";

const LoginMethod = EmberObject.extend({
  @computed
  title() {
    return this.title_override || I18n.t(`login.${this.name}.title`);
  },

  @computed
  prettyName() {
    return this.pretty_name_override || I18n.t(`login.${this.name}.name`);
  },

  @computed
  message() {
    return this.message_override || I18n.t(`login.${this.name}.message`);
  },

  doLogin({ reconnect = false } = {}) {
    if (this.customLogin) {
      this.customLogin();
      return Ember.RSVP.resolve();
    }

    if (this.custom_url) {
      window.location = this.custom_url;
      return Ember.RSVP.resolve();
    }

    let authUrl = Discourse.getURL(`/auth/${this.name}`);

    if (reconnect) {
      authUrl += "?reconnect=true";
    }

    return LoginMethod.buildPostForm(authUrl).then(form => form.submit());
  }
});

LoginMethod.reopenClass({
  buildPostForm(url) {
    // Login always happens in an anonymous context, with no CSRF token
    // So we need to fetch it before sending a POST request
    return updateCsrfToken().then(() => {
      const form = document.createElement("form");
      form.setAttribute("style", "display:none;");
      form.setAttribute("method", "post");
      form.setAttribute("action", url);

      const input = document.createElement("input");
      input.setAttribute("name", "authenticity_token");
      input.setAttribute("value", Discourse.Session.currentProp("csrfToken"));
      form.appendChild(input);

      document.body.appendChild(form);

      return form;
    });
  }
});

let methods;

export function findAll() {
  if (methods) return methods;

  methods = [];

  Discourse.Site.currentProp("auth_providers").forEach(provider =>
    methods.pushObject(LoginMethod.create(provider))
  );

  // exclude FA icon for Google, uses custom SVG
  methods.forEach(m => m.set("isGoogle", m.name === "google_oauth2"));

  return methods;
}

export default LoginMethod;
