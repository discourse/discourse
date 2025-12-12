import EmbedMode from "discourse/lib/embed-mode";
import { i18n } from "discourse-i18n";

function isSafari() {
  const ua = navigator.userAgent;
  return (
    ua.includes("Safari") && !ua.includes("Chrome") && !ua.includes("Chromium")
  );
}

export default {
  after: "inject-objects",

  initialize(owner) {
    if (!EmbedMode.enabled) {
      return;
    }

    // Storage Access API is needed for Safari's ITP (Intelligent Tracking Prevention)
    // which blocks third-party cookies in iframes. Other browsers don't need this.
    if (!isSafari()) {
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

  showStorageAccessPrompt(owner) {
    const siteSettings = owner.lookup("service:site-settings");
    const siteName = siteSettings.title || "this forum";

    const promptText = i18n("embed_mode.storage_access_prompt", {
      site_name: siteName,
    });
    const allowText = i18n("embed_mode.allow_access");
    const guestText = i18n("embed_mode.continue_as_guest");

    const overlay = document.createElement("div");
    overlay.className = "embed-storage-access-overlay";

    const prompt = document.createElement("div");
    prompt.className = "embed-storage-access-prompt";

    const p = document.createElement("p");
    p.textContent = promptText;

    const primaryBtn = document.createElement("button");
    primaryBtn.className = "btn btn-primary";
    primaryBtn.textContent = allowText;

    const guestBtn = document.createElement("button");
    guestBtn.className = "btn btn-flat btn-text";
    guestBtn.textContent = guestText;

    prompt.appendChild(p);
    prompt.appendChild(primaryBtn);
    prompt.appendChild(guestBtn);
    overlay.appendChild(prompt);

    primaryBtn.addEventListener("click", async () => {
      try {
        await document.requestStorageAccess();
        // Reload to get the session cookie
        window.location.reload();
      } catch {
        // User denied or browser blocked - just dismiss
        overlay.remove();
      }
    });

    guestBtn.addEventListener("click", () => {
      overlay.remove();
    });

    document.body.appendChild(overlay);
  },
};
