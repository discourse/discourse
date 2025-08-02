import Controller from "@ember/controller";
import { action, get } from "@ember/object";
import { equal } from "@ember/object/computed";
import { service } from "@ember/service";
import { isBlank } from "@ember/utils";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import ApiKeyUrlsModal from "../components/modal/api-key-urls";

export default class AdminApiKeysNewController extends Controller {
  @service router;
  @service modal;

  userModes = [
    { id: "all", name: i18n("admin.api.all_users") },
    { id: "single", name: i18n("admin.api.single_user") },
  ];
  scopeModes = [
    { id: "granular", name: i18n("admin.api.scopes.granular") },
    { id: "read_only", name: i18n("admin.api.scopes.read_only") },
    { id: "global", name: i18n("admin.api.scopes.global") },
  ];
  globalScopes = null;
  scopes = null;

  @equal("userMode", "single") showUserSelector;

  init() {
    super.init(...arguments);
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
    this.router.transitionTo("adminApiKeys.show", this.model.id);
  }

  @action
  showURLs(urls) {
    this.modal.show(ApiKeyUrlsModal, {
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
