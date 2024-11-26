import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import ConditionalLoadingSection from "discourse/components/conditional-loading-section";
import CopyButton from "discourse/components/copy-button";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import withEventValue from "discourse/helpers/with-event-value";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import dIcon from "discourse-common/helpers/d-icon";
import { POPULAR_THEMES } from "discourse-common/lib/popular-themes";
import { i18n } from "discourse-i18n";
import InstallThemeItem from "admin/components/install-theme-item";
import { COMPONENTS, THEMES } from "admin/models/theme";
import ComboBox from "select-kit/components/combo-box";

const MIN_NAME_LENGTH = 4;
const CREATE_TYPES = [
  { name: i18n("admin.customize.theme.theme"), value: THEMES },
  { name: i18n("admin.customize.theme.component"), value: COMPONENTS },
];

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

  willDestroy() {
    super.willDestroy(...arguments);
    this.args.model.clearParams?.();
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
      return i18n("admin.customize.theme.component_name");
    } else {
      return i18n("admin.customize.theme.theme_name");
    }
  }

  get themes() {
    return POPULAR_THEMES.map((popularTheme) => {
      if (
        this.args.model.installedThemes.some((installedTheme) =>
          this.themeHasSameUrl(installedTheme, popularTheme.value)
        )
      ) {
        popularTheme.installed = true;
      }
      return popularTheme;
    });
  }

  themeHasSameUrl(theme, url) {
    const themeUrl = theme.remote_theme?.remote_url;
    return (
      themeUrl &&
      url &&
      url.replace(/\.git$/, "") === themeUrl.replace(/\.git$/, "")
    );
  }

  @action
  async generatePublicKey() {
    try {
      const pair = await ajax(this.keyGenUrl, {
        type: "POST",
      });
      this.publicKey = pair.public_key;
    } catch (err) {
      popupAjaxError(err);
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
      } catch (err) {
        popupAjaxError(err);
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
        const warning = i18n("admin.customize.theme.duplicate_remote_theme", {
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
    } catch (err) {
      if (!this.publicKey || this.themeCannotBeInstalled) {
        return popupAjaxError(err);
      }
      this.themeCannotBeInstalled = i18n("admin.customize.theme.force_install");
    } finally {
      this.loading = false;
    }
  }

  <template>
    <DModal
      @bodyClass="install-theme"
      class="admin-install-theme-modal"
      @title={{i18n "admin.customize.theme.install"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        {{#unless this.directRepoInstall}}
          <div class="install-theme-items">
            <InstallThemeItem
              @value="popular"
              @selection={{this.selection}}
              @label="admin.customize.theme.install_popular"
            />
            <InstallThemeItem
              @value="local"
              @selection={{this.selection}}
              @label="admin.customize.theme.install_upload"
            />
            <InstallThemeItem
              @value="remote"
              @selection={{this.selection}}
              @label="admin.customize.theme.install_git_repo"
            />
            <InstallThemeItem
              @value="create"
              @selection={{this.selection}}
              @label="admin.customize.theme.install_create"
              @showIcon={{true}}
            />
          </div>
        {{/unless}}
        <div class="install-theme-content">
          <ConditionalLoadingSection
            @isLoading={{this.loading}}
            @title={{i18n "admin.customize.theme.installing_message"}}
          >
            {{#if this.popular}}
              <div class="popular-theme-items">
                {{#each this.themes as |theme|}}
                  <div class="popular-theme-item" data-name={{theme.name}}>
                    <div class="popular-theme-name">
                      <a
                        href={{theme.meta_url}}
                        rel="noopener noreferrer"
                        target="_blank"
                      >
                        {{#if theme.component}}
                          {{dIcon
                            "puzzle-piece"
                            title="admin.customize.theme.component"
                          }}
                        {{/if}}
                        {{theme.name}}
                      </a>
                      <div class="popular-theme-description">
                        {{theme.description}}
                      </div>
                    </div>

                    <div class="popular-theme-buttons">
                      {{#if theme.installed}}
                        <span>{{i18n "admin.customize.theme.installed"}}</span>
                      {{else}}
                        <DButton
                          class="btn-small"
                          @label="admin.customize.theme.install"
                          @disabled={{this.installDisabled}}
                          @icon="upload"
                          @action={{fn this.installThemeFromList theme.value}}
                        />

                        {{#if theme.preview}}
                          <a
                            href={{theme.preview}}
                            rel="noopener noreferrer"
                            target="_blank"
                          >
                            {{dIcon "desktop"}}
                            {{i18n "admin.customize.theme.preview"}}
                          </a>
                        {{/if}}
                      {{/if}}
                    </div>
                  </div>
                {{/each}}
              </div>
            {{/if}}
            {{#if this.local}}
              <div class="inputs">
                <input
                  {{on "change" this.uploadLocaleFile}}
                  type="file"
                  id="file-input"
                  accept=".dcstyle.json,application/json,.tar.gz,application/x-gzip,.zip,application/zip"
                />
                <br />
                <span class="description">
                  {{i18n "admin.customize.theme.import_file_tip"}}
                </span>
              </div>
            {{/if}}
            {{#if this.remote}}
              <div class="inputs">
                <div class="repo">
                  <div class="label">
                    {{i18n "admin.customize.theme.import_web_tip"}}
                  </div>
                  <input
                    type="text"
                    {{on "input" (withEventValue (fn (mut this.uploadUrl)))}}
                    value={{this.uploadUrl}}
                    placeholder={{this.urlPlaceholder}}
                  />
                </div>
                <DButton
                  class="btn-small advanced-repo"
                  @action={{this.toggleAdvanced}}
                  @label="admin.customize.theme.import_web_advanced"
                />
                {{#if this.advancedVisible}}
                  <div class="branch">
                    <div class="label">
                      {{i18n "admin.customize.theme.remote_branch"}}
                    </div>
                    <input
                      type="text"
                      {{on "input" (withEventValue (fn (mut this.branch)))}}
                      value={{this.branch}}
                      placeholder="main"
                    />
                  </div>
                {{/if}}
                {{#if this.showPublicKey}}
                  <div class="public-key">
                    <div class="label">
                      {{i18n "admin.customize.theme.public_key"}}
                    </div>
                    <div class="public-key-text-wrapper">
                      <textarea
                        class="public-key-value"
                        readonly="true"
                        {{on
                          "input"
                          (withEventValue (fn (mut this.publicKey)))
                        }}
                        value={{this.publicKey}}
                        {{didInsert this.generatePublicKey}}
                      />
                      <CopyButton @selector="textarea.public-key-value" />
                    </div>
                  </div>
                {{/if}}
              </div>
            {{/if}}
            {{#if this.create}}
              <div class="inputs">
                <div class="label">{{i18n
                    "admin.customize.theme.create_name"
                  }}</div>
                <input
                  type="text"
                  {{on "input" (withEventValue (fn (mut this.name)))}}
                  value={{this.name}}
                  placeholder={{this.placeholder}}
                />
                <div class="label">{{i18n
                    "admin.customize.theme.create_type"
                  }}</div>
                <ComboBox
                  @valueProperty="value"
                  @content={{CREATE_TYPES}}
                  @value={{this.selectedType}}
                  @onChange={{this.updateSelectedType}}
                />
              </div>
            {{/if}}
            {{#if this.directRepoInstall}}
              <div class="repo">
                <div class="label">
                  {{htmlSafe
                    (i18n
                      "admin.customize.theme.direct_install_tip"
                      name=this.uploadName
                    )
                  }}
                </div>
                <pre><code>{{this.uploadUrl}}</code></pre>
              </div>
            {{/if}}
          </ConditionalLoadingSection>
        </div>
      </:body>
      <:footer>
        {{#unless this.popular}}
          {{#if this.duplicateRemoteThemeWarning}}
            <div class="install-theme-warning">
              ⚠️
              {{this.duplicateRemoteThemeWarning}}
            </div>
          {{/if}}
          {{#if this.themeCannotBeInstalled}}
            <div class="install-theme-warning">
              ⚠️
              {{this.themeCannotBeInstalled}}
            </div>
          {{/if}}
          <DButton
            @action={{this.installTheme}}
            @disabled={{this.installDisabled}}
            class={{if this.themeCannotBeInstalled "btn-danger" "btn-primary"}}
            @label={{this.submitLabel}}
          />
          <DButton
            class="btn-flat d-modal-cancel"
            @action={{@closeModal}}
            @label="cancel"
          />
        {{/unless}}
      </:footer>
    </DModal>
  </template>
}
