import Service, { service } from "@ember/service";

export default class RestrictedRouting extends Service {
  @service currentUser;
  @service siteSettings;

  get isRestricted() {
    return this._needsRequiredFields || this._needs2fa;
  }

  isAllowedRoute(path) {
    const alwaysAllowed = ["faq", "about", "tos", "privacy", "safe-mode"];

    if (alwaysAllowed.includes(path)) {
      return true;
    }

    if (this._needs2fa) {
      if (path === "preferences.second-factor") {
        return true;
      }

      return false;
    }

    if (this._needsRequiredFields) {
      if (path.startsWith("admin")) {
        return true;
      }

      if (path === "preferences.profile") {
        return true;
      }

      return false;
    }

    return true;
  }

  get redirectRoute() {
    if (this._needs2fa) {
      return "preferences.second-factor";
    }

    if (this._needsRequiredFields) {
      return "preferences.profile";
    }
  }

  get _needs2fa() {
    // NOTE: Matches the should_enforce_2fa? and disqualified_from_2fa_enforcement
    // methods in ApplicationController.
    const enforcing2fa =
      (this.siteSettings.enforce_second_factor === "staff" &&
        this.currentUser?.staff) ||
      this.siteSettings.enforce_second_factor === "all";

    const exemptedFrom2faEnforcement =
      !this.currentUser ||
      this.currentUser.is_anonymous ||
      this.currentUser.second_factor_enabled ||
      (!this.siteSettings.enforce_second_factor_on_external_auth &&
        this.currentUser.login_method === "oauth");

    return enforcing2fa && !exemptedFrom2faEnforcement;
  }

  get _needsRequiredFields() {
    return this.currentUser?.needs_required_fields_check;
  }
}
