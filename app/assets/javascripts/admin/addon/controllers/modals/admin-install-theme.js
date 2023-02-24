import { COMPONENTS, THEMES } from "admin/models/theme";
import { inject as controller } from "@ember/controller";
import { alias, equal, match } from "@ember/object/computed";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import I18n from "I18n";
import Modal from "discourse/controllers/modal";
import { POPULAR_THEMES } from "discourse-common/helpers/popular-themes";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { set } from "@ember/object";

const MIN_NAME_LENGTH = 4;

export default Modal.extend({
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
  urlPlaceholder: "https://github.com/discourse/sample_theme",

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

  @observes("checkPrivate")
  privateWasChecked() {
    const checked = this.checkPrivate;
    if (checked && !this._keyLoading && !this.publicKey) {
      this._keyLoading = true;
      ajax(this.keyGenUrl, { type: "POST" })
        .then((pair) => {
          this.set("publicKey", pair.public_key);
        })
        .catch(popupAjaxError)
        .finally(() => {
          this._keyLoading = false;
        });
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

  @discourseComputed("checkPrivate", "publicKey")
  showPublicKey(checkPrivate, publicKey) {
    return checkPrivate && publicKey;
  },

  onClose() {
    this.setProperties({
      duplicateRemoteThemeWarning: null,
      localFile: null,
      uploadUrl: null,
      publicKey: null,
      branch: null,
      selection: "popular",
    });

    this.themesController.setProperties({
      repoName: null,
      repoUrl: null,
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
          public_key: this.publicKey,
        };
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
          this.set("publicKey", null);
        })
        .catch((error) => {
          if (!this.publicKey || this.themeCannotBeInstalled) {
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
