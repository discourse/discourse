import Controller from "@ember/controller";
import EmberObject, { action } from "@ember/object";
import {
  empty,
  filterBy,
  mapBy,
  match,
  notEmpty,
  readOnly,
} from "@ember/object/computed";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { url } from "discourse/lib/computed";
import { makeArray } from "discourse-common/lib/helpers";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";
import ThemeSettingsEditor from "admin/components/theme-settings-editor";
import { COMPONENTS, THEMES } from "admin/models/theme";
import ThemeSettings from "admin/models/theme-settings";
import ThemeUploadAddModal from "../components/theme-upload-add";

const THEME_UPLOAD_VAR = 2;

export default class AdminCustomizeThemesShowController extends Controller {
  @service dialog;
  @service router;
  @service siteSettings;
  @service modal;

  editRouteName = "adminCustomizeThemes.edit";

  @url("model.id", "/admin/customize/themes/%@/export") downloadUrl;
  @url("model.id", "/admin/themes/%@/preview") previewUrl;
  @url("model.id", "model.locale", "/admin/themes/%@/translations/%@")
  getTranslationsUrl;
  @empty("selectedChildThemeId") addButtonDisabled;
  @mapBy("model.parentThemes", "name") parentThemesNames;
  @filterBy("allThemes", "component", false) availableParentThemes;
  @filterBy("availableParentThemes", "isActive") availableActiveParentThemes;
  @mapBy("availableParentThemes", "name") availableThemesNames;
  @mapBy("availableActiveParentThemes", "name") availableActiveThemesNames;
  @filterBy("availableChildThemes", "hasParents") availableActiveChildThemes;
  @mapBy("availableChildThemes", "name") availableComponentsNames;
  @mapBy("availableActiveChildThemes", "name") availableActiveComponentsNames;
  @mapBy("model.childThemes", "name") childThemesNames;
  @filterBy("model.theme_fields", "target", "extra_js") extraFiles;
  @notEmpty("settings") hasSettings;
  @notEmpty("translations") hasTranslations;
  @match("model.remote_theme.remote_url", /^http(s)?:\/\//) sourceIsHttp;
  @readOnly("model.settings") settings;

  @discourseComputed("model.component", "model.remote_theme")
  showCheckboxes() {
    return !this.model.component || this.model.remote_theme;
  }

  @discourseComputed("model.editedFields")
  editedFieldsFormatted() {
    const descriptions = [];
    ["common", "desktop", "mobile"].forEach((target) => {
      const fields = this.editedFieldsForTarget(target);
      if (fields.length < 1) {
        return;
      }
      let resultString = i18n("admin.customize.theme." + target);
      const formattedFields = fields
        .map((f) => i18n("admin.customize.theme." + f.name + ".text"))
        .join(" , ");
      resultString += `: ${formattedFields}`;
      descriptions.push(resultString);
    });
    return descriptions;
  }

  @discourseComputed("colorSchemeId", "model.color_scheme_id")
  colorSchemeChanged(colorSchemeId, existingId) {
    colorSchemeId = colorSchemeId === null ? null : parseInt(colorSchemeId, 10);
    return colorSchemeId !== existingId;
  }

  @discourseComputed("availableChildThemes", "model.childThemes.[]", "model")
  selectableChildThemes(available, childThemes) {
    if (available) {
      const themes = !childThemes
        ? available
        : available.filter((theme) => !childThemes.includes(theme));
      return themes.length === 0 ? null : themes;
    }
  }

  @discourseComputed("model.parentThemes.[]")
  relativesSelectorSettingsForComponent() {
    return EmberObject.create({
      list_type: "compact",
      type: "list",
      preview: null,
      anyValue: false,
      setting: "parent_theme_ids",
      label: i18n("admin.customize.theme.component_on_themes"),
      choices: this.availableThemesNames,
      default: this.parentThemesNames.join("|"),
      value: this.parentThemesNames.join("|"),
      defaultValues: this.availableActiveThemesNames.join("|"),
      allThemes: this.allThemes,
      setDefaultValuesLabel: i18n("admin.customize.theme.add_all_themes"),
    });
  }

  @discourseComputed("model.parentThemes.[]")
  relativesSelectorSettingsForTheme() {
    return EmberObject.create({
      list_type: "compact",
      type: "list",
      preview: null,
      anyValue: false,
      setting: "child_theme_ids",
      label: i18n("admin.customize.theme.included_components"),
      choices: this.availableComponentsNames,
      default: this.childThemesNames.join("|"),
      value: this.childThemesNames.join("|"),
      defaultValues: this.availableActiveComponentsNames.join("|"),
      allThemes: this.allThemes,
      setDefaultValuesLabel: i18n("admin.customize.theme.add_all"),
    });
  }

  @discourseComputed("allThemes", "model.component", "model")
  availableChildThemes(allThemes) {
    if (!this.get("model.component")) {
      const themeId = this.get("model.id");
      return allThemes.filter(
        (theme) => theme.get("id") !== themeId && theme.get("component")
      );
    }
  }

  @discourseComputed("model.component")
  convertKey(component) {
    const type = component ? "component" : "theme";
    return `admin.customize.theme.convert_${type}`;
  }

  @discourseComputed("model.component")
  convertIcon(component) {
    return component ? "cube" : "";
  }

  @discourseComputed("model.component")
  convertTooltip(component) {
    const type = component ? "component" : "theme";
    return `admin.customize.theme.convert_${type}_tooltip`;
  }

  @discourseComputed("model.translations")
  translations(translations) {
    return translations.map((setting) =>
      ThemeSettings.create({ ...setting, textarea: true })
    );
  }

  @discourseComputed(
    "model.remote_theme.local_version",
    "model.remote_theme.remote_version",
    "model.remote_theme.commits_behind"
  )
  hasOverwrittenHistory(localVersion, remoteVersion, commitsBehind) {
    return localVersion !== remoteVersion && commitsBehind === -1;
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

  editedFieldsForTarget(target) {
    return this.get("model.editedFields").filter(
      (field) => field.target === target
    );
  }

  commitSwitchType() {
    const model = this.model;
    const newValue = !model.get("component");
    model.set("component", newValue);

    if (newValue) {
      this.set("parentController.currentTab", COMPONENTS);
    } else {
      this.set("parentController.currentTab", THEMES);
    }

    model
      .saveChanges("component")
      .then(() => {
        this.set("colorSchemeId", null);

        model.setProperties({
          default: false,
          color_scheme_id: null,
          user_selectable: false,
          child_themes: [],
          childThemes: [],
        });

        this.get("parentController.model.content").forEach((theme) => {
          const children = makeArray(theme.get("childThemes"));
          const rawChildren = makeArray(theme.get("child_themes"));
          const index = children ? children.indexOf(model) : -1;
          if (index > -1) {
            children.splice(index, 1);
            rawChildren.splice(index, 1);
            theme.setProperties({
              childThemes: children,
              child_themes: rawChildren,
            });
          }
        });
      })
      .catch(popupAjaxError);
  }

  transitionToEditRoute() {
    this.router.transitionTo(
      this.editRouteName,
      this.get("model.id"),
      "common",
      "scss"
    );
  }

  @discourseComputed(
    "model.remote_theme.remote_url",
    "model.remote_theme.branch"
  )
  remoteThemeLink(remoteThemeUrl, remoteThemeBranch) {
    return remoteThemeBranch
      ? `${remoteThemeUrl.replace(/\.git$/, "")}/tree/${remoteThemeBranch}`
      : remoteThemeUrl;
  }

  @discourseComputed("model.user.id", "model.default")
  showConvert(userId, defaultTheme) {
    return userId > 0 && !defaultTheme;
  }

  @action
  refreshModel() {
    this.send("routeRefreshModel");
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
  checkForThemeUpdates() {
    this.set("updatingRemote", true);
    this.model
      .checkForUpdates()
      .catch(popupAjaxError)
      .finally(() => {
        this.set("updatingRemote", false);
      });
  }

  @action
  addUploadModal() {
    this.modal.show(ThemeUploadAddModal, {
      model: {
        themeFields: this.model.theme_fields,
        addUpload: this.addUpload,
      },
    });
  }

  @action
  addUpload(info) {
    let model = this.model;
    model.setField("common", info.name, "", info.upload_id, THEME_UPLOAD_VAR);
    model.saveChanges("theme_fields").catch((e) => popupAjaxError(e));
  }

  get availableLocales() {
    return JSON.parse(this.siteSettings.available_locales);
  }

  get locale() {
    return (
      this.get("model.locale") ||
      this.userLocale ||
      this.siteSettings.default_locale
    );
  }

  @action
  updateLocale(value) {
    this.set("model.locale", value);
    ajax(this.getTranslationsUrl).then(({ translations }) =>
      this.set("model.translations", translations)
    );
  }

  @action
  cancelChangeScheme() {
    this.set("colorSchemeId", this.get("model.color_scheme_id"));
  }

  @action
  changeScheme() {
    let schemeId = this.colorSchemeId;
    this.set(
      "model.color_scheme_id",
      schemeId === null ? null : parseInt(schemeId, 10)
    );
    this.model.saveChanges("color_scheme_id");
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
  editTheme() {
    if (this.get("model.remote_theme.is_git")) {
      this.dialog.confirm({
        message: i18n("admin.customize.theme.edit_confirm"),
        didConfirm: () => this.transitionToEditRoute(),
      });
    } else {
      this.transitionToEditRoute();
    }
  }

  @action
  applyDefault() {
    const model = this.model;
    model.saveChanges("default").then(() => {
      if (model.get("default")) {
        this.allThemes.forEach((theme) => {
          if (theme !== model && theme.get("default")) {
            theme.set("default", false);
          }
        });
      }
    });
  }

  @action
  applyUserSelectable() {
    this.model.saveChanges("user_selectable");
  }

  @action
  applyAutoUpdateable() {
    this.model.saveChanges("auto_update");
  }

  @action
  addChildTheme() {
    let themeId = parseInt(this.selectedChildThemeId, 10);
    let theme = this.allThemes.findBy("id", themeId);
    this.model.addChildTheme(theme).then(() => this.store.findAll("theme"));
  }

  @action
  removeUpload(upload) {
    return this.dialog.yesNoConfirm({
      message: i18n("admin.customize.theme.delete_upload_confirm"),
      didConfirm: () => this.model.removeField(upload),
    });
  }

  @action
  removeChildTheme(theme) {
    this.model.removeChildTheme(theme).then(() => this.store.findAll("theme"));
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
          this.router.transitionTo("adminCustomizeThemes");
        });
      },
    });
  }

  @action
  showThemeSettingsEditor() {
    this.dialog.alert({
      title: "Edit Settings",
      bodyComponent: ThemeSettingsEditor,
      bodyComponentModel: { model: this.model, controller: this },
      class: "theme-settings-editor-dialog",
    });
  }

  @action
  switchType() {
    const relatives = this.get("model.component")
      ? this.get("model.parentThemes")
      : this.get("model.childThemes");

    let message = i18n(`${this.convertKey}_alert_generic`);

    if (relatives && relatives.length > 0) {
      message = i18n(`${this.convertKey}_alert`, {
        relatives: relatives.map((relative) => relative.get("name")).join(", "),
      });
    }

    return this.dialog.yesNoConfirm({
      message,
      didConfirm: () => this.commitSwitchType(),
    });
  }

  @action
  enableComponent() {
    this.model.set("enabled", true);
    this.model
      .saveChanges("enabled")
      .catch(() => this.model.set("enabled", false));
  }

  @action
  disableComponent() {
    this.model.set("enabled", false);
    this.model
      .saveChanges("enabled")
      .catch(() => this.model.set("enabled", true));
  }

  @action
  editColorScheme() {
    this.router.transitionTo("adminCustomize.colors.show", this.colorSchemeId);
  }
}
