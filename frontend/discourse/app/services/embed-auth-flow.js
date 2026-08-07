import Service, { service } from "@ember/service";
import EmbedAuthFlowModal from "discourse/components/modal/embed-auth-flow";
import { ajax } from "discourse/lib/ajax";
import EmbedMode from "discourse/lib/embed-mode";
import getURL from "discourse/lib/get-url";

const SESSION_POLL_INTERVAL_MS = 3000;
const SESSION_POLL_MAX_MS = 5 * 60 * 1000;

export default class EmbedAuthFlow extends Service {
  @service modal;
  @service siteSettings;

  _popup = null;
  _pollTimer = null;
  _pollStartedAt = null;
  _pollInFlight = false;

  willDestroy() {
    super.willDestroy(...arguments);
    this._stopPolling();
  }

  get isActive() {
    // The flow assumes the iframe can receive its cookies after popup
    // sign-in — true when the embed is same-site to the host page (any
    // SameSite setting) or when SameSite=None is configured for cross-site
    // embeds. Validating that at runtime would need the Public Suffix List;
    // we trust the admin to enable this only on a compatible deployment.
    return EmbedMode.enabled && this.siteSettings.embed_full_app_signin_flow;
  }

  get _supportsStorageAccess() {
    return (
      typeof document.hasStorageAccess === "function" &&
      typeof document.requestStorageAccess === "function"
    );
  }

  get _siteName() {
    return this.siteSettings.title;
  }

  async requestAccess({ intent = "login" } = {}) {
    if (!this.isActive) {
      return false;
    }

    // hasStorageAccess() is the browser-agnostic signal for cookie
    // partitioning — returns true on same-site embeds (and same-origin
    // iframes) where nothing's blocked, false when the iframe's cookie jar
    // is partitioned (Safari ITP, Firefox Total Cookie Protection, Chrome
    // 3p cookie phaseout). When partitioned we bridge via Storage Access
    // so the iframe's post-signin polling can see the popup's cookies.
    if (!this._supportsStorageAccess) {
      // Old browser with no API to bridge — fall back to a top-level login
      // tab so the user isn't dead-ended inside the iframe.
      this._openLegacyLoginTab(intent);
      return true;
    }

    let hasAccess;
    try {
      hasAccess = await document.hasStorageAccess();
    } catch {
      hasAccess = false;
    }

    if (!hasAccess) {
      this._promptForStorageAccess(intent);
      return true;
    }

    // We have access — if the user is already signed in to Discourse in
    // another tab, the iframe was just missing the cookie due to
    // partitioning. Reloading is enough; no popup needed.
    if (await this._isUserSignedIn()) {
      this._reload();
      return true;
    }

    this._promptForSignin(intent);
    return true;
  }

  _promptForStorageAccess(intent) {
    this.modal.show(EmbedAuthFlowModal, {
      model: {
        kind: "storage-access",
        siteName: this._siteName,
        // Runs synchronously inside the button's click handler so user
        // activation is valid for requestStorageAccess().
        onConfirm: () => {
          document
            .requestStorageAccess()
            .then(() => {
              // Re-run requestAccess so the unified post-access path runs
              // — including the already-signed-in check, which otherwise
              // sends the user through an unnecessary popup that just
              // bounces back to the homepage.
              this.requestAccess({ intent });
            })
            .catch(() => {
              // Storage access was denied; the iframe cannot access the
              // session even after a sign-in popup, so chaining one would
              // dead-end. The user can retry their original action to be
              // re-prompted.
            });
        },
      },
    });
  }

  async _isUserSignedIn() {
    try {
      await ajax("/session/current.json");
      return true;
    } catch {
      return false;
    }
  }

  _reload() {
    window.location.reload();
  }

  _promptForSignin(intent) {
    this.modal.show(EmbedAuthFlowModal, {
      model: {
        kind: "signin",
        siteName: this._siteName,
        // Runs synchronously inside the button's click handler so the popup
        // is not blocked.
        onConfirm: () => {
          this._openSigninPopup(intent);
        },
        onCancel: () => {
          this._stopPolling();
        },
      },
    });
  }

  _openLegacyLoginTab(intent) {
    const path = intent === "signup" ? "/signup" : "/login";
    window.open(getURL(path), "_blank");
  }

  _openSigninPopup(intent) {
    const path = intent === "signup" ? "/signup" : "/login";
    const url = new URL(getURL(path), window.location.origin);
    url.searchParams.set("embed_signin_callback", "1");

    const popup = window.open(url.toString(), "_blank");
    if (!popup) {
      return;
    }

    this._popup = popup;
    this._startPolling();
  }

  _startPolling() {
    // Polled rather than postMessage-driven because OAuth providers (e.g.
    // Discourse ID) typically set Cross-Origin-Opener-Policy, which severs
    // window.opener once the popup navigates off-origin — so the popup
    // can't reliably signal success back. The iframe just watches the
    // session endpoint directly.
    this._pollStartedAt = Date.now();
    this._pollTimer = setInterval(
      () => this._pollOnce(),
      SESSION_POLL_INTERVAL_MS
    );
  }

  async _pollOnce() {
    if (this._pollInFlight) {
      return;
    }

    const elapsed = Date.now() - this._pollStartedAt;
    if (elapsed > SESSION_POLL_MAX_MS) {
      this._giveUpWaiting();
      return;
    }

    this._pollInFlight = true;
    try {
      await ajax("/session/current.json");
      this._handleSigninSuccess();
    } catch {
      // 404 (not signed in) or transient — keep polling.
    } finally {
      this._pollInFlight = false;
    }
  }

  _stopPolling() {
    if (this._pollTimer) {
      clearInterval(this._pollTimer);
      this._pollTimer = null;
    }
    if (this._popup && !this._popup.closed) {
      this._popup.close();
    }
    this._popup = null;
    this._pollStartedAt = null;
  }

  _giveUpWaiting() {
    // Polling expired without a sign-in — dismiss the waiting modal so the
    // user isn't left staring at a spinner that's no longer doing anything.
    this._stopPolling();
    this.modal.close();
  }

  _handleSigninSuccess() {
    this._stopPolling();
    // Storage access (when needed) was granted before the popup opened and
    // persists across iframe reload, so reloading is enough to pick up the
    // session cookie that the popup just established first-party.
    this._reload();
  }
}
