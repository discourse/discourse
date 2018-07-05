import computed from "ember-addons/ember-computed-decorators";

const LoginMethod = Ember.Object.extend({
  @computed
  title() {
    const titleSetting = this.get("titleSetting");
    if (!Ember.isEmpty(titleSetting)) {
      const result = this.siteSettings[titleSetting];
      if (!Ember.isEmpty(result)) {
        return result;
      }
    }

    return (
      this.get("titleOverride") ||
      I18n.t("login." + this.get("name") + ".title")
    );
  },

  @computed
  prettyName() {
    return I18n.t("login." + this.get("name") + ".name");
  },

  @computed
  message() {
    return (
      this.get("messageOverride") ||
      I18n.t("login." + this.get("name") + ".message")
    );
  },

  doLogin() {
    const name = this.get("name");
    const customLogin = this.get("customLogin");

    if (customLogin) {
      customLogin();
    } else {
      let authUrl = this.get("customUrl") || Discourse.getURL("/auth/" + name);
      if (this.get("fullScreenLogin")) {
        document.cookie = "fsl=true";
        window.location = authUrl;
      } else {
        this.set("authenticate", name);
        const left = this.get("lastX") - 400;
        const top = this.get("lastY") - 200;

        const height = this.get("frameHeight") || 400;
        const width = this.get("frameWidth") || 800;

        if (this.get("displayPopup")) {
          authUrl = authUrl + "?display=popup";
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
let preRegister;

export const LOGIN_METHODS = [
  "google_oauth2",
  "facebook",
  "twitter",
  "yahoo",
  "instagram",
  "github"
];

export function findAll(siteSettings, capabilities, isMobileDevice) {
  if (methods) {
    return methods;
  }

  methods = [];

  LOGIN_METHODS.forEach(name => {
    if (siteSettings["enable_" + name + "_logins"]) {
      const params = { name };
      if (name === "google_oauth2") {
        params.frameWidth = 850;
        params.frameHeight = 500;
      } else if (name === "facebook") {
        params.frameWidth = 580;
        params.frameHeight = 400;
        params.displayPopup = true;
      }

      if (["facebook"].includes(name)) {
        params.canConnect = true;
      }

      params.siteSettings = siteSettings;
      methods.pushObject(LoginMethod.create(params));
    }
  });

  if (preRegister) {
    preRegister.forEach(method => {
      const enabledSetting = method.get("enabledSetting");
      if (enabledSetting) {
        if (siteSettings[enabledSetting]) {
          methods.pushObject(method);
        }
      } else {
        methods.pushObject(method);
      }
    });
    preRegister = undefined;
  }

  // On Mobile, Android or iOS always go with full screen
  if (isMobileDevice || capabilities.isIOS || capabilities.isAndroid) {
    methods.forEach(m => m.set("fullScreenLogin", true));
  }

  return methods;
}

export function register(method) {
  method = LoginMethod.create(method);
  if (methods) {
    methods.pushObject(method);
  } else {
    preRegister = preRegister || [];
    preRegister.push(method);
  }
}

export default LoginMethod;
