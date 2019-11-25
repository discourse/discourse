import PreloadStore from "preload-store";
import { userPath } from "discourse/lib/url";

export default {
  name: "too-many-sessions",
  after: "inject-objects",
  initialize() {
    PreloadStore.getAndRemove("destroyedSessions").then(value => {
      if (!(value && value.count)) return;

      const message = I18n.t("too_many_sessions", {
        count: value.count,
        limit: value.limit,
        url: userPath("preferences/account")
      });

      bootbox.alert(message);
    });
  }
};
