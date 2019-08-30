import computed from "ember-addons/ember-computed-decorators";
import { updateCsrfToken } from "discourse/lib/ajax";

const LoginMethod = Ember.Object.extend({
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

  doLogin({ reconnect = false, fullScreenLogin = true } = {}) {
    const name = this.name;
    const customLogin = this.customLogin;

    if (customLogin) {
      customLogin();
    } else {
      if (this.custom_url) {
        window.location = this.custom_url;
        return;
      }
      let authUrl = Discourse.getURL(`/auth/${name}`);

      if (reconnect) {
        authUrl += "?reconnect=true";
      }

      if (reconnect || fullScreenLogin || this.full_screen_login) {
        LoginMethod.buildPostForm(authUrl).then(form => {
          document.cookie = "fsl=true";
          form.submit();
        });
      } else {
        this.set("authenticate", name);
        const left = this.lastX - 400;
        const top = this.lastY - 200;

        const height = this.frame_height || 400;
        const width = this.frame_width || 800;

        if (name === "facebook") {
          authUrl += authUrl.includes("?") ? "&" : "?";
          authUrl += "display=popup";
        }
        LoginMethod.buildPostForm(authUrl).then(form => {
          const windowState = window.open(
            authUrl,
            "auth_popup",
            `menubar=no,status=no,height=${height},width=${width},left=${left},top=${top}`
          );

          form.target = "auth_popup";
          form.submit();

          const timer = setInterval(() => {
            // If the process is aborted, reset state in this window
            if (!windowState || windowState.closed) {
              clearInterval(timer);
              this.set("authenticate", null);
            }
          }, 1000);
        });
      }
    }
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
