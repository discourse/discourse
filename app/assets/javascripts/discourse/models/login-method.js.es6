import computed from 'ember-addons/ember-computed-decorators';

const LoginMethod = Ember.Object.extend({
  @computed
  title() {

    const titleSetting = this.get('titleSetting');
    if (!Ember.isEmpty(titleSetting)) {
      const result = this.siteSettings[titleSetting];
      if (!Ember.isEmpty(result)) { return result; }
    }

    return this.get("titleOverride") || I18n.t("login." + this.get("name") + ".title");
  },

  @computed
  message() {
    return this.get("messageOverride") || I18n.t("login." + this.get("name") + ".message");
  }
});

let methods;
let preRegister;

export function findAll(siteSettings) {
  if (methods) { return methods; }

  methods = [];

  [ "google_oauth2", "facebook", "cas", "twitter", "yahoo", "instagram", "github" ].forEach(name => {
    if (siteSettings["enable_" + name + "_logins"]) {
      const params = { name };
      if (name === "google_oauth2") {
        params.frameWidth = 850;
        params.frameHeight = 500;
      } else if (name === "facebook") {
        params.frameHeight = 450;
      }

      params.siteSettings = siteSettings;
      methods.pushObject(LoginMethod.create(params));
    }
  });

  if (preRegister){
    preRegister.forEach(method => {
      const enabledSetting = method.get('enabledSetting');
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
