import Controller from "@ember/controller";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import { isBlank } from "@ember/utils";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { get } from "@ember/object";
import showModal from "discourse/lib/show-modal";

export default Controller.extend({
  userModes: [
    { id: "all", name: I18n.t("admin.api.all_users") },
    { id: "single", name: I18n.t("admin.api.single_user") },
  ],
  useGlobalKey: false,
  scopes: null,

  @discourseComputed("userMode")
  showUserSelector(mode) {
    return mode === "single";
  },

  @discourseComputed("model.description", "model.username", "userMode")
  saveDisabled(description, username, userMode) {
    if (isBlank(description)) {
      return true;
    }
    if (userMode === "single" && isBlank(username)) {
      return true;
    }
    return false;
  },

  actions: {
    updateUsername(selected) {
      this.set("model.username", get(selected, "firstObject"));
    },

    changeUserMode(value) {
      if (value === "all") {
        this.model.set("username", null);
      }
      this.set("userMode", value);
    },

    save() {
      if (!this.useGlobalKey) {
        const selectedScopes = Object.values(this.scopes)
          .flat()
          .filter((action) => {
            return action.selected;
          });

        this.model.set("scopes", selectedScopes);
      }

      this.model.save().catch(popupAjaxError);
    },

    continue() {
      this.transitionToRoute("adminApiKeys.show", this.model.id);
    },

    showURLs(urls) {
      return showModal("admin-api-key-urls", {
        admin: true,
        model: {
          urls,
        },
      });
    },
  },
});
