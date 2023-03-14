import { equal } from "@ember/object/computed";
import Controller from "@ember/controller";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import { isBlank } from "@ember/utils";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { action, get } from "@ember/object";
import showModal from "discourse/lib/show-modal";
import { ajax } from "discourse/lib/ajax";

export default class AdminApiKeysNewController extends Controller {
  userModes = null;
  scopeModes = null;
  globalScopes = null;
  scopes = null;

  @equal("userMode", "single") showUserSelector;
  init() {
    super.init(...arguments);

    this.set("userModes", [
      { id: "all", name: I18n.t("admin.api.all_users") },
      { id: "single", name: I18n.t("admin.api.single_user") },
    ]);

    this.set("scopeModes", [
      { id: "granular", name: I18n.t("admin.api.scopes.granular") },
      { id: "read_only", name: I18n.t("admin.api.scopes.read_only") },
      { id: "global", name: I18n.t("admin.api.scopes.global") },
    ]);

    this._loadScopes();
  }

  @discourseComputed("model.{description,username}", "showUserSelector")
  saveDisabled(model, showUserSelector) {
    if (isBlank(model.description)) {
      return true;
    }
    if (showUserSelector && isBlank(model.username)) {
      return true;
    }
    return false;
  }

  @action
  updateUsername(selected) {
    this.set("model.username", get(selected, "firstObject"));
  }

  @action
  changeUserMode(userMode) {
    if (userMode === "all") {
      this.model.set("username", null);
    }
    this.set("userMode", userMode);
  }

  @action
  changeScopeMode(scopeMode) {
    this.set("scopeMode", scopeMode);
  }

  @action
  save() {
    if (this.scopeMode === "granular") {
      const selectedScopes = Object.values(this.scopes)
        .flat()
        .filterBy("selected");

      this.model.set("scopes", selectedScopes);
    } else if (this.scopeMode === "read_only") {
      this.model.set("scopes", [this.globalScopes.findBy("key", "read")]);
    } else if (this.scopeMode === "all") {
      this.model.set("scopes", null);
    }

    return this.model.save().catch(popupAjaxError);
  }

  @action
  continue() {
    this.transitionToRoute("adminApiKeys.show", this.model.id);
  }

  @action
  showURLs(urls) {
    return showModal("admin-api-key-urls", {
      admin: true,
      model: { urls },
    });
  }

  _loadScopes() {
    return ajax("/admin/api/keys/scopes.json")
      .then((data) => {
        // remove global scopes because there is a different dropdown
        this.set("globalScopes", data.scopes.global);
        delete data.scopes.global;

        this.set("scopes", data.scopes);
      })
      .catch(popupAjaxError);
  }
}
