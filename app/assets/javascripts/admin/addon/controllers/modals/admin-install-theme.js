import { COMPONENTS, THEMES } from "admin/models/theme";
import Controller, { inject as controller } from "@ember/controller";
import { alias, equal, match } from "@ember/object/computed";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import I18n from "I18n";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { POPULAR_THEMES } from "discourse-common/helpers/popular-themes";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { set } from "@ember/object";

const MIN_NAME_LENGTH = 4;

export default Controller.extend(ModalFunctionality, {
  adminCustomizeThemes: controller(),
  themesController: controller("adminCustomizeThemes"),
  popular: equal("selection", "popular"),
  local: equal("selection", "local"),
  remote: equal("selection", "remote"),
  create: equal("selection", "create"),
  directRepoInstall: equal("selection", "directRepoInstall"),
  selection: "popular",
  loading: false,
  keyGenUrl: "/admin/themes/generate_key_pair",
  importUrl: "/admin/themes/import",
  recordType: "theme",
  checkPrivate: match("uploadUrl", /^ssh:\/\/.+@.+$|.+@.+:.+$/),
  localFile: null,
  uploadUrl: null,
  uploadName: null,
  advancedVisible: false,
  selectedType: alias("themesController.currentTab"),
  component: equal("selectedType", COMPONENTS),

  init() {
    this._super(...arguments);

    this.createTypes = [
      { name: I18n.t("admin.customize.theme.theme"), value: THEMES },
      { name: I18n.t("admin.customize.theme.component"), value: COMPONENTS },
    ];
  },

  @discourseComputed("themesController.installedThemes")
  themes(installedThemes) {
    return POPULAR_THEMES.map((t) => {
      if (
        installedThemes.some((theme) => this.themeHasSameUrl(theme, t.value))
      ) {
        set(t, "installed", true);
      }
      return t;
    });
  },

  @discourseComputed(
    "loading",
    "remote",
    "uploadUrl",
    "local",
    "localFile",
    "create",
    "nameTooShort"
  )
  installDisabled(
    isLoading,
    isRemote,
    uploadUrl,
    isLocal,
    localFile,
    isCreate,
    nameTooShort
  ) {
    return (
      isLoading ||
      (isRemote && !uploadUrl) ||
      (isLocal && !localFile) ||
      (isCreate && nameTooShort)
    );
  },

  @discourseComputed("privateChecked")
  urlPlaceholder(privateChecked) {
    return privateChecked
      ? "git@github.com:discourse/sample_theme.git"
      : "https://github.com/discourse/sample_theme";
  },

  @observes("privateChecked")
  privateWasChecked() {
    const checked = this.privateChecked;
    if (checked && !this._keyLoading) {
      this._keyLoading = true;
      ajax(this.keyGenUrl, { type: "POST" })
        .then((pair) => {
          this.setProperties({
            privateKey: pair.private_key,
            publicKey: pair.public_key,
          });
        })
        .catch(popupAjaxError)
        .finally(() => {
          this._keyLoading = false;
        });
    }
  },

  @discourseComputed("name")
  nameTooShort(name) {
    return !name || name.length < MIN_NAME_LENGTH;
  },

  @discourseComputed("component")
  placeholder(component) {
    if (component) {
      return I18n.t("admin.customize.theme.component_name");
    } else {
      return I18n.t("admin.customize.theme.theme_name");
    }
  },

  @discourseComputed("selection", "themeCannotBeInstalled")
  submitLabel(selection, themeCannotBeInstalled) {
    if (themeCannotBeInstalled) {
      return "admin.customize.theme.create_placeholder";
    }

    return `admin.customize.theme.${
      selection === "create" ? "create" : "install"
    }`;
  },

  @discourseComputed("privateChecked", "checkPrivate", "publicKey")
  showPublicKey(privateChecked, checkPrivate, publicKey) {
    return privateChecked && checkPrivate && publicKey;
  },

  onClose() {
    this.setProperties({
      duplicateRemoteThemeWarning: null,
      privateChecked: false,
      privateKey: null,
      localFile: null,
      uploadUrl: null,
      publicKey: null,
      branch: null,
      selection: "popular",
    });
  },

  themeHasSameUrl(theme, url) {
    const themeUrl = theme.remote_theme && theme.remote_theme.remote_url;
    return (
      themeUrl &&
      url &&
      url.replace(/\.git$/, "") === themeUrl.replace(/\.git$/, "")
    );
  },

  actions: {
    uploadLocaleFile() {
      this.set("localFile", $("#file-input")[0].files[0]);
    },

    toggleAdvanced() {
      this.toggleProperty("advancedVisible");
    },

    installThemeFromList(url) {
      this.set("uploadUrl", url);
      this.send("installTheme");
    },

    installTheme() {
      if (this.create) {
        this.set("loading", true);
        const theme = this.store.createRecord(this.recordType);
        theme
          .save({ name: this.name, component: this.component })
          .then(() => {
            this.themesController.send("addTheme", theme);
            this.send("closeModal");
          })
          .catch(popupAjaxError)
          .finally(() => this.set("loading", false));

        return;
      }

      let options = {
        type: "POST",
      };

      if (this.local) {
        options.processData = false;
        options.contentType = false;
        options.data = new FormData();
        options.data.append("theme", this.localFile);
      }

      if (this.remote || this.popular || this.directRepoInstall) {
        const duplicate = this.themesController.model.content.find((theme) =>
          this.themeHasSameUrl(theme, this.uploadUrl)
        );
        if (duplicate && !this.duplicateRemoteThemeWarning) {
          const warning = I18n.t(
            "admin.customize.theme.duplicate_remote_theme",
            { name: duplicate.name }
          );
          this.set("duplicateRemoteThemeWarning", warning);
          return;
        }
        options.data = {
          remote: this.uploadUrl,
          branch: this.branch,
        };

        if (this.privateChecked) {
          options.data.private_key = this.privateKey;
        }
      }

      // User knows that theme cannot be installed, but they want to continue
      // to force install it.
      if (this.themeCannotBeInstalled) {
        options.data["force"] = true;
      }

      if (this.get("model.user_id")) {
        // Used by theme-creator
        options.data["user_id"] = this.get("model.user_id");
      }

      this.set("loading", true);
      ajax(this.importUrl, options)
        .then((result) => {
          const theme = this.store.createRecord(this.recordType, result.theme);
          this.adminCustomizeThemes.send("addTheme", theme);
          this.send("closeModal");
        })
        .then(() => {
          this.setProperties({ privateKey: null, publicKey: null });
        })
        .catch((error) => {
          if (!this.privateKey || this.themeCannotBeInstalled) {
            return popupAjaxError(error);
          }

          this.set(
            "themeCannotBeInstalled",
            I18n.t("admin.customize.theme.force_install")
          );
        })
        .finally(() => this.set("loading", false));
    },
  },
});
