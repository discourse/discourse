import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { alias, equal, match } from "@ember/object/computed";
import { COMPONENTS, THEMES } from "admin/models/theme";
import { POPULAR_THEMES } from "discourse-common/lib/popular-themes";
import { ajax } from "discourse/lib/ajax";
import I18n from "I18n";

const MIN_NAME_LENGTH = 4;

export default class InstallTheme extends Component {
  @alias("args.adminCustomizeThemes") themesController;
  @alias("themesController.currentTab") selectedType;
  @equal("selectedType", COMPONENTS) component;

  @tracked selection = "popular";
  @tracked loading = false;
  @tracked keyGenUrl = "/admin/themes/generate_key_pair";
  @tracked importUrl = "/admin/themes/import";
  @tracked recordType = "theme";
  @tracked checkPrivate = null;
  @tracked localFile = null;
  @tracked uploadUrl = null;
  @tracked uploadName = null;
  @tracked advancedVisible = false;
  @tracked publicKey = null;
  @tracked branch = null;
  @tracked duplicateRemoteThemeWarning = null;

  @match("uploadUrl", /^ssh:\/\/.+@.+$|.+@.+:.+$/) checkPrivate;

  get local() {
    return this.selection === "local";
  }

  get remote() {
    return this.selection === "remote";
  }

  get create() {
    return this.selection === "create";
  }

  get directRepoInstall() {
    return this.selection === "directRepoInstall";
  }

  get popular() {
    return this.selection === "popular";
  }

  get nameTooShort() {
    return !this.name || this.name.length < MIN_NAME_LENGTH;
  }

  get installDisabled() {
    return (
      this.loading ||
      (this.remote && !this.uploadUrl) ||
      (this.local && !this.localFile) ||
      (this.create && this.nameTooShort)
    );
  }

  get placeholder() {
    if (this.component) {
      return I18n.t("admin.customize.theme.component_name");
    } else {
      return I18n.t("admin.customize.theme.theme_name");
    }
  }

  get themes() {
    return POPULAR_THEMES.map((t) => {
      if (
        this.themesController.installedThemes.some((theme) =>
          this.themeHasSameUrl(theme, t.value)
        )
      ) {
        set(t, "installed", true);
      }
      return t;
    });
  }

  themeHasSameUrl(theme, url) {
    const themeUrl = theme.remote_theme && theme.remote_theme.remote_url;
    return (
      themeUrl &&
      url &&
      url.replace(/\.git$/, "") === themeUrl.replace(/\.git$/, "")
    );
  }

  @action
  privateWasChecked() {
    const checked = this.checkPrivate;
    if (checked && !this._keyLoading && !this.publicKey) {
      this._keyLoading = true;
      ajax(this.keyGenUrl, { type: "POST" })
        .then((pair) => {
          this.publicKey = pair.public_key;
        })
        .catch(popupAjaxError)
        .finally(() => {
          this._keyLoading = false;
        });
    }
  }

  @action
  toggleAdvanced() {
    this.advancedVisible = !this.advancedVisible;
  }

  @action
  onClose() {
    this.duplicateRemoteThemeWarning = null;
    this.localFile = null;
    this.uploadUrl = null;
    this.publicKey = null;
    this.branch = null;
    this.selection = "popular";

    this.themesController.repoName = null;
    this.themesController.repoUrl = null;
  }

  @action
  uploadLocaleFile() {
    this.localFile = document.getElementById("file-input").files[0];
  }

  @action
  installThemeFromList(url) {
    this.uploadUrl = url;
    this.installTheme();
  }

  @action
  installTheme() {
    if (this.create) {
      this.loading = true;
      const theme = this.store.createRecord(this.recordType);
      theme
        .save({ name: this.name, component: this.component })
        .then(() => {
          this.themesController.addTheme(theme);
          this.modalFunctionality.send("closeModal");
        })
        .catch(popupAjaxError)
        .finally(() => (this.loading = false));

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
        const warning = I18n.t("admin.customize.theme.duplicate_remote_theme", {
          name: duplicate.name,
        });
        this.duplicateRemoteThemeWarning = warning;
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

    if (this.model.user_id) {
      // Used by theme-creator
      options.data["user_id"] = this.model.user_id;
    }

    this.loading = true;
    ajax(this.importUrl, options)
      .then((result) => {
        const theme = this.store.createRecord(this.recordType, result.theme);
        this.themesController.addTheme(theme);
        this.modalFunctionality.send("closeModal");
      })
      .then(() => {
        this.publicKey = null;
      })
      .catch((error) => {
        if (!this.publicKey || this.themeCannotBeInstalled) {
          return popupAjaxError(error);
        }

        this.themeCannotBeInstalled = I18n.t(
          "admin.customize.theme.force_install"
        );
      })
      .finally(() => (this.loading = false));
  }
}
