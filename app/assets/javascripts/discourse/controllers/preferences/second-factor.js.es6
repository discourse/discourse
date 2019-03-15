import { default as computed } from "ember-addons/ember-computed-decorators";
import { default as DiscourseURL, userPath } from "discourse/lib/url";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { findAll } from "discourse/models/login-method";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";

export default Ember.Controller.extend({
  loading: false,
  resetPasswordLoading: false,
  resetPasswordProgress: "",
  password: null,
  secondFactorImage: null,
  secondFactorKey: null,
  showSecondFactorKey: false,
  errorMessage: null,
  newUsername: null,
  backupEnabled: Ember.computed.alias("model.second_factor_backup_enabled"),
  secondFactorMethod: SECOND_FACTOR_METHODS.TOTP,

  loaded: Ember.computed.and("secondFactorImage", "secondFactorKey"),

  @computed("loading")
  submitButtonText(loading) {
    return loading ? "loading" : "continue";
  },

  @computed("loading")
  enableButtonText(loading) {
    return loading ? "loading" : "enable";
  },

  @computed("loading")
  disableButtonText(loading) {
    return loading ? "loading" : "disable";
  },

  @computed
  displayOAuthWarning() {
    return findAll().length > 0;
  },

  @computed(
    "siteSettings.enforce_second_factor",
    "currentUser",
    "currentUser.second_factor_enabled",
    "currentUser.staff"
  )
  showEnforcedNotice(
    enforce_second_factor,
    user,
    second_factor_enabled,
    staff
  ) {
    return (
      user &&
      !second_factor_enabled &&
      (enforce_second_factor === "all" ||
        (enforce_second_factor === "staff" && staff))
    );
  },

  toggleSecondFactor(enable) {
    if (!this.get("secondFactorToken")) return;
    this.set("loading", true);

    this.get("model")
      .toggleSecondFactor(
        this.get("secondFactorToken"),
        this.get("secondFactorMethod"),
        SECOND_FACTOR_METHODS.TOTP,
        enable
      )
      .then(response => {
        if (response.error) {
          this.set("errorMessage", response.error);
          return;
        }

        this.set("errorMessage", null);
        DiscourseURL.redirectTo(
          userPath(`${this.get("model").username.toLowerCase()}/preferences`)
        );
      })
      .catch(error => {
        popupAjaxError(error);
      })
      .finally(() => this.set("loading", false));
  },

  actions: {
    confirmPassword() {
      if (!this.get("password")) return;
      this.set("loading", true);

      this.get("model")
        .loadSecondFactorCodes(this.get("password"))
        .then(response => {
          if (response.error) {
            this.set("errorMessage", response.error);
            return;
          }

          this.setProperties({
            errorMessage: null,
            secondFactorKey: response.key,
            secondFactorImage: response.qr
          });
        })
        .catch(popupAjaxError)
        .finally(() => this.set("loading", false));
    },

    resetPassword() {
      this.setProperties({
        resetPasswordLoading: true,
        resetPasswordProgress: ""
      });

      return this.get("model")
        .changePassword()
        .then(() => {
          this.set(
            "resetPasswordProgress",
            I18n.t("user.change_password.success")
          );
        })
        .catch(popupAjaxError)
        .finally(() => this.set("resetPasswordLoading", false));
    },

    showSecondFactorKey() {
      this.set("showSecondFactorKey", true);
    },

    enableSecondFactor() {
      this.toggleSecondFactor(true);
    },

    disableSecondFactor() {
      this.toggleSecondFactor(false);
    }
  }
});
