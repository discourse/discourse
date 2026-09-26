import { lookup } from "discourse/lib/service";
import { isTesting } from "discourse/lib/environment";
import getURL from "discourse/lib/get-url";
import SiteSettingsService from "discourse/services/site-settings";
import CurrentUserService from "discourse/services/current-user";

export async function restoredSessionMatches(bootedUserId) {
  try {
    const response = await fetch(getURL("/session/current.json"), {
      headers: { Accept: "application/json" },
    });

    if (response.status === 404) {
      return bootedUserId === null;
    }

    if (!response.ok) {
      return true;
    }

    const json = await response.json();
    return (json.current_user?.id ?? null) === bootedUserId;
  } catch {
    return true;
  }
}

export default {
  initialize(owner) {
    if (isTesting()) {
      return;
    }

    const siteSettings = lookup(owner, SiteSettingsService);
    if (!siteSettings.cache_control_bfcache_compatibility) {
      return;
    }

    const bootedUserId = lookup(owner, CurrentUserService)?.id ?? null;

    this.handler = async (event) => {
      if (event.persisted && !(await restoredSessionMatches(bootedUserId))) {
        window.location.reload();
      }
    };

    window.addEventListener("pageshow", this.handler);
  },

  teardown() {
    window.removeEventListener("pageshow", this.handler);
  },
};
