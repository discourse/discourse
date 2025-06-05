import Controller from "@ember/controller";
import { action } from "@ember/object";
import { match } from "@ember/object/computed";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class AdminCustomizeThemesShowController extends Controller {
  @service dialog;
  @service router;

  @match("model.remote_theme.remote_url", /^http(s)?:\/\//) sourceIsHttp;

  @discourseComputed(
    "model.remote_theme.remote_url",
    "model.remote_theme.branch"
  )
  remoteThemeLink(remoteThemeUrl, remoteThemeBranch) {
    return remoteThemeBranch
      ? `${remoteThemeUrl.replace(/\.git$/, "")}/tree/${remoteThemeBranch}`
      : remoteThemeUrl;
  }

  @discourseComputed("model.remoteError", "updatingRemote")
  showRemoteError(errorMessage, updating) {
    return errorMessage && !updating;
  }

  @discourseComputed(
    "model.remote_theme.remote_url",
    "model.remote_theme.local_version",
    "model.remote_theme.commits_behind"
  )
  finishInstall(remoteUrl, localVersion, commitsBehind) {
    return remoteUrl && !localVersion && !commitsBehind;
  }

  @action
  startEditingName() {
    this.set("oldName", this.get("model.name"));
    this.set("editingName", true);
  }

  @action
  cancelEditingName() {
    this.set("model.name", this.oldName);
    this.set("editingName", false);
  }

  @action
  finishedEditingName() {
    this.model.saveChanges("name");
    this.set("editingName", false);
  }

  @action
  updateToLatest() {
    this.set("updatingRemote", true);
    this.model
      .updateToLatest()
      .catch(popupAjaxError)
      .finally(() => {
        this.set("updatingRemote", false);
      });
  }

  @action
  destroyTheme() {
    return this.dialog.yesNoConfirm({
      message: i18n("admin.customize.delete_confirm", {
        theme_name: this.get("model.name"),
      }),
      didConfirm: () => {
        const model = this.model;
        model.setProperties({ recentlyInstalled: false });
        model.destroyRecord().then(() => {
          this.allThemes.removeObject(model);
          this.router.transitionTo("adminConfig.customize.themes");
        });
      },
    });
  }

  @action
  enableComponent() {
    this.model.set("enabled", true);
    this.model
      .saveChanges("enabled")
      .catch(() => this.model.set("enabled", false));
  }
}
