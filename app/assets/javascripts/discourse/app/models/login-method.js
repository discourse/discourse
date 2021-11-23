import EmberObject from "@ember/object";
import I18n from "I18n";
import { Promise } from "rsvp";
import Session from "discourse/models/session";
import Site from "discourse/models/site";
import discourseComputed from "discourse-common/utils/decorators";
import getURL from "discourse-common/lib/get-url";
import { updateCsrfToken } from "discourse/lib/ajax";

const LoginMethod = EmberObject.extend({
  @discourseComputed
  title() {
    return this.title_override || I18n.t(`login.${this.name}.title`);
  },

  @discourseComputed
  screenReaderTitle() {
    return (
      this.title_override ||
      I18n.t(`login.${this.name}.sr_title`, { defaultValue: this.title })
    );
  },

  @discourseComputed
  prettyName() {
    return this.pretty_name_override || I18n.t(`login.${this.name}.name`);
  },

  doLogin({ reconnect = false, signup = false, params = {} } = {}) {
    if (this.customLogin) {
      this.customLogin();
      return Promise.resolve();
    }

    if (this.custom_url) {
      window.location = this.custom_url;
      return Promise.resolve();
    }

    let authUrl = getURL(`/auth/${this.name}`);

    if (reconnect) {
      params["reconnect"] = true;
    }

    if (signup) {
      params["signup"] = true;
    }

    const paramKeys = Object.keys(params);
    if (paramKeys.length > 0) {
      authUrl += "?";
      authUrl += paramKeys
        .map((k) => `${encodeURIComponent(k)}=${encodeURIComponent(params[k])}`)
        .join("&");
    }

    return LoginMethod.buildPostForm(authUrl).then((form) => form.submit());
  },
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
      input.setAttribute("value", Session.currentProp("csrfToken"));
      form.appendChild(input);

      document.body.appendChild(form);

      return form;
    });
  },
});

let methods;

export function findAll() {
  if (methods) {
    return methods;
  }

  methods = Site.currentProp("auth_providers").map((provider) =>
    LoginMethod.create(provider)
  );

  // exclude FA icon for Google, uses custom SVG
  methods.forEach((m) => m.set("isGoogle", m.name === "google_oauth2"));

  return methods;
}

export function clearAuthMethods() {
  methods = undefined;
}

export default LoginMethod;
