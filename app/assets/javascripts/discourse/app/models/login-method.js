import EmberObject from "@ember/object";
import { Promise } from "rsvp";
import { updateCsrfToken } from "discourse/lib/ajax";
import Session from "discourse/models/session";
import Site from "discourse/models/site";
import getURL from "discourse-common/lib/get-url";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

export default class LoginMethod extends EmberObject {
  static buildPostForm(url) {
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
  }

  @discourseComputed
  title() {
    return this.title_override || i18n(`login.${this.name}.title`);
  }

  @discourseComputed
  screenReaderTitle() {
    return (
      this.title_override ||
      i18n(`login.${this.name}.sr_title`, { defaultValue: this.title })
    );
  }

  @discourseComputed
  prettyName() {
    return this.pretty_name_override || i18n(`login.${this.name}.name`);
  }

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
  }
}

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
