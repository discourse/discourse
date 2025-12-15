import EmbedMode from "discourse/lib/embed-mode";
import { i18n } from "discourse-i18n";

export default {
  after: "inject-objects",

  initialize(owner) {
    if (!EmbedMode.enabled) {
      return;
    }

    const capabilities = owner.lookup("service:capabilities");

    // Storage Access API is needed for Safari's ITP (Intelligent Tracking Prevention)
    // which blocks third-party cookies in iframes. Other browsers don't need this.
    if (!capabilities.isSafari) {
      return;
    }

    if (!document.hasStorageAccess || !document.requestStorageAccess) {
      return;
    }

    const currentUser = owner.lookup("service:current-user");

    // If user is already logged in, storage access is working
    if (currentUser) {
      return;
    }

    // Check if we have storage access
    document.hasStorageAccess().then((hasAccess) => {
      if (hasAccess) {
        // We have storage access but no user - they're genuinely not logged in
        return;
      }

      // Show a prompt to request storage access
      this.showStorageAccessPrompt(owner);
    });
  },

  async showStorageAccessPrompt(owner) {
    const dialog = owner.lookup("service:dialog");
    const siteSettings = owner.lookup("service:site-settings");
    const siteName = siteSettings.title || "this forum";

    const confirmed = await dialog.confirm({
      message: i18n("embed_mode.storage_access_prompt", {
        site_name: siteName,
      }),
      confirmButtonLabel: "embed_mode.allow_access",
      cancelButtonLabel: "embed_mode.continue_as_guest",
    });

    if (confirmed) {
      try {
        await document.requestStorageAccess();
        // Reload to get the session cookie
        window.location.reload();
      } catch {
        // User denied or browser blocked - silently continue as guest
      }
    }
  },
};
