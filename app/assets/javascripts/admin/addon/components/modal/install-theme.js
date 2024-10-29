import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { POPULAR_THEMES } from "discourse-common/lib/popular-themes";
import I18n from "discourse-i18n";
import { COMPONENTS, THEMES } from "admin/models/theme";

const MIN_NAME_LENGTH = 4;

export default class InstallThemeModal extends Component {
  @service store;

  @tracked selection = this.args.model.selection || "popular";
  @tracked uploadUrl = this.args.model.uploadUrl;
  @tracked uploadName = this.args.model.uploadName;
  @tracked selectedType = this.args.model.selectedType;
  @tracked advancedVisible = false;
  @tracked loading = false;
  @tracked localFile;
  @tracked publicKey;
  @tracked branch;
  @tracked duplicateRemoteThemeWarning;
  @tracked themeCannotBeInstalled;
  @tracked name;

  recordType = this.args.model.recordType || "theme";
  keyGenUrl = this.args.model.keyGenUrl || "/admin/themes/generate_key_pair";
  importUrl = this.args.model.importUrl || "/admin/themes/import";

  get createTypes() {
    return [
      { name: I18n.t("admin.customize.theme.theme"), value: THEMES },
      { name: I18n.t("admin.customize.theme.component"), value: COMPONENTS },
    ];
  }

  get showPublicKey() {
    return this.uploadUrl?.match?.(/^ssh:\/\/.+@.+$|.+@.+:.+$/);
  }

  get submitLabel() {
    if (this.themeCannotBeInstalled) {
      return "admin.customize.theme.create_placeholder";
    }

    return `admin.customize.theme.${this.create ? "create" : "install"}`;
  }

  get component() {
    return this.selectedType === COMPONENTS;
  }

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
        this.args.model.installedThemes.some((theme) =>
          this.themeHasSameUrl(theme, t.value)
        )
      ) {
        t.installed = true;
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

  willDestroy() {
    super.willDestroy(...arguments);
    this.args.model.clearParams?.();
  }

  @action
  async generatePublicKey() {
    try {
      const pair = await ajax(this.keyGenUrl, {
        type: "POST",
      });
      this.publicKey = pair.public_key;
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  toggleAdvanced() {
    this.advancedVisible = !this.advancedVisible;
  }

  @action
  uploadLocaleFile(event) {
    this.localFile = event.target.files[0];
  }

  @action
  updateSelectedType(type) {
    this.args.model.updateSelectedType(type);
    this.selectedType = type;
  }

  @action
  installThemeFromList(url) {
    this.uploadUrl = url;
    this.installTheme();
  }

  @action
  async installTheme() {
    if (this.create) {
      this.loading = true;
      const theme = this.store.createRecord(this.recordType);
      try {
        await theme.save({ name: this.name, component: this.component });
        this.args.model.addTheme(theme);
        this.args.closeModal();
      } catch (e) {
        popupAjaxError(e);
      } finally {
        this.loading = false;
      }
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
      const duplicate =
        this.args.model.content &&
        this.args.model.content.find((theme) =>
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

    // Used by theme-creator
    if (this.args.model.userId) {
      options.data["user_id"] = this.args.model.userId;
    }

    try {
      this.loading = true;
      const result = await ajax(this.importUrl, options);
      const theme = this.store.createRecord(this.recordType, result.theme);
      this.args.model.addTheme(theme);
      this.args.closeModal();
    } catch (e) {
      if (!this.publicKey || this.themeCannotBeInstalled) {
        return popupAjaxError(e);
      }
      this.themeCannotBeInstalled = I18n.t(
        "admin.customize.theme.force_install"
      );
    } finally {
      this.loading = false;
    }
  }
}
