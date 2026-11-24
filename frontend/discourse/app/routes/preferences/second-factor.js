import RestrictedUserRoute from "discourse/routes/restricted-user";

export default class PreferencesSecondFactor extends RestrictedUserRoute {
  model() {
    return this.modelFor("user");
  }

  beforeModel() {
    const user = this.modelFor("user");
    if (!user.isCurrent) {
      if (
        this.currentUser?.enforcedSecondFactor &&
        !this.currentUser.is_anonymous
      ) {
        this.router.replaceWith("preferences.second-factor", this.currentUser);
      } else {
        this.router.replaceWith(
          user.can_edit ? "preferences.security" : "userActivity"
        );
      }
    } else if (user.is_anonymous) {
      this.router.replaceWith("userActivity");
    }
  }

  setupController(controller, model, transition) {
    super.setupController(controller, model, transition);
    controller.markDirty();
    controller.loadSecondFactors({
      onEntry: true,
      confirmOnEntry: transition.data.confirmSecondFactorSession,
    });
  }

  resetController(controller, isExiting) {
    if (isExiting) {
      controller.resetFactorLoad();
    }
  }
}
