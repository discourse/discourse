import { adoptAnonymousFlatRepliesPreference } from "discourse/lib/nested-view-preference";

export default {
  initialize(owner) {
    // Errors are left for the next boot to retry, since the key stays set.
    adoptAnonymousFlatRepliesPreference(
      owner.lookup("service:current-user"),
      owner.lookup("service:key-value-store")
    ).catch(() => {});
  },
};
