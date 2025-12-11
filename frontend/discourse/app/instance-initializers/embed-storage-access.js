import EmbedMode from "discourse/lib/embed-mode";

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

    const overlay = document.createElement("div");
    overlay.className = "embed-storage-access-overlay";
    overlay.innerHTML = `
      <div class="embed-storage-access-prompt">
        <p>Already have a ${siteName} account? Allow access to your session to comment as yourself.</p>
        <button class="btn btn-primary">Allow Access</button>
        <button class="btn btn-flat btn-text">Continue as Guest</button>
      </div>
    `;

    const primaryBtn = overlay.querySelector(".btn-primary");
    const guestBtn = overlay.querySelector(".btn-text");

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
