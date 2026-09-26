import { lookup } from "discourse/lib/service";
import CurrentUserService from "discourse/services/current-user";

// The wizard sheet outlives the page it was opened from: picking a theme is a
// different asset build, so previewing one reloads the whole page. Resuming has
// to happen at boot rather than from whichever component opened the sheet, or
// only the onboarding banner could ever survive that reload.
export default {
  initialize(owner) {
    const currentUser = lookup(owner, CurrentUserService);
    if (!currentUser?.admin) {
      return;
    }

    import("discourse/services/design-wizard").then((module) =>
      this.resume(owner, currentUser, module)
    );
  },

  resume(
    owner,
    currentUser,
    { default: DesignWizardService, DESIGN_WIZARD_PARAM, SOURCE_ADMIN }
  ) {
    const designWizard = lookup(owner, DesignWizardService);
    const params = new URLSearchParams(window.location.search);

    if (params.get(DESIGN_WIZARD_PARAM)) {
      if (!currentUser.can_run_design_wizard) {
        return;
      }

      // the sheet previews the page behind it, so the link is meant for a forum
      // page; the parameter is dropped so a refresh does not reopen the wizard.
      // The history API rather than the router, which has not booted yet
      params.delete(DESIGN_WIZARD_PARAM);
      const search = params.toString();
      window.history.replaceState(
        null,
        "",
        `${window.location.pathname}${search ? `?${search}` : ""}`
      );

      designWizard.start({ source: SOURCE_ADMIN });
      return;
    }

    designWizard.resumeAfterThemePreview();
  },
};
