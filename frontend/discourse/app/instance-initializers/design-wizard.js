import {
  DESIGN_WIZARD_PARAM,
  SOURCE_ADMIN,
} from "discourse/services/design-wizard";

// The wizard sheet outlives the page it was opened from: picking a theme is a
// different asset build, so previewing one reloads the whole page. Resuming has
// to happen at boot rather than from whichever component opened the sheet, or
// only the onboarding banner could ever survive that reload.
export default {
  initialize(owner) {
    const currentUser = owner.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    const designWizard = owner.lookup("service:design-wizard");
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
