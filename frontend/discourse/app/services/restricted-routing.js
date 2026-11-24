import Service, { service } from "@ember/service";

export default class RestrictedRouting extends Service {
  @service currentUser;

  get isRestricted() {
    return this._needsRequiredFields || this._needs2fa;
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
    return (
      this.currentUser?.enforcedSecondFactor && !this.currentUser.is_anonymous
    );
  }

  get _needsRequiredFields() {
    return this.currentUser?.needs_required_fields_check;
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
}
