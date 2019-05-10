import computed from "ember-addons/ember-computed-decorators";

const LoginMethod = Ember.Object.extend({
  @computed
  title() {
    return (
      this.get("title_override") || I18n.t(`login.${this.get("name")}.title`)
    );
  },

  @computed
  prettyName() {
    return (
      this.get("pretty_name_override") ||
      I18n.t(`login.${this.get("name")}.name`)
    );
  },

  @computed
  message() {
    return (
      this.get("message_override") ||
      I18n.t("login." + this.get("name") + ".message")
    );
  },

  doLogin({ reconnect = false, fullScreenLogin = true } = {}) {
    const name = this.get("name");
    const customLogin = this.get("customLogin");

    if (customLogin) {
      customLogin();
    } else {
      let authUrl = this.get("custom_url") || Discourse.getURL("/auth/" + name);

      if (reconnect) {
        authUrl += "?reconnect=true";
      }

      if (fullScreenLogin) {
        document.cookie = "fsl=true";
        window.location = authUrl;
      } else {
        this.set("authenticate", name);
        const left = this.get("lastX") - 400;
        const top = this.get("lastY") - 200;

        const height = this.get("frame_height") || 400;
        const width = this.get("frame_width") || 800;

        if (name === "facebook") {
          authUrl += authUrl.includes("?") ? "&" : "?";
          authUrl += "display=popup";
        }

        const w = window.open(
          authUrl,
          "_blank",
          "menubar=no,status=no,height=" +
            height +
            ",width=" +
            width +
            ",left=" +
            left +
            ",top=" +
            top
        );
        const self = this;
        const timer = setInterval(function() {
          if (!w || w.closed) {
            clearInterval(timer);
            self.set("authenticate", null);
          }
        }, 1000);
      }
    }
  }
});

let methods;

export function findAll() {
  if (methods) {
    return methods;
  }

  methods = [];

  Discourse.Site.currentProp("auth_providers").forEach(provider => {
    methods.pushObject(LoginMethod.create(provider));
  });

  // exclude FA icon for Google, uses custom SVG
  methods.forEach(m => m.set("isGoogle", m.get("name") === "google_oauth2"));

  return methods;
}

export default LoginMethod;
