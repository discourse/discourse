const SESSION_KEY_PENDING = "discourse:embed:popup-callback";

export default {
  after: "inject-objects",

  initialize(owner) {
    // The query param is the only reliable signal — Discourse's default COOP
    // (`same-origin-allow-popups`) mismatches a typical embedding host's
    // (`unsafe-none`), which severs `window.opener` on the first popup load.
    if (paramPresent()) {
      try {
        sessionStorage.setItem(SESSION_KEY_PENDING, "1");
      } catch {}
    }

    let pending = false;
    try {
      pending = sessionStorage.getItem(SESSION_KEY_PENDING) === "1";
    } catch {}

    if (!pending) {
      return;
    }

    const currentUser = owner.lookup("service:current-user");
    if (!currentUser) {
      return;
    }

    try {
      sessionStorage.removeItem(SESSION_KEY_PENDING);
    } catch {}

    // The iframe detects sign-in via session polling, so this self-close is
    // just UX — silently no-ops if window.close() is disallowed.
    window.close();
  },
};

function paramPresent() {
  try {
    const params = new URLSearchParams(window.location.search);
    return params.get("embed_signin_callback") === "1";
  } catch {
    return false;
  }
}
