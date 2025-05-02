import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import Form from "discourse/components/form";
import UserLink from "discourse/components/user-link";
import icon from "discourse/helpers/d-icon";
import formatDate from "discourse/helpers/format-date";
import formatUsername from "discourse/helpers/format-username";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import ColorPaletteEditor, {
  LIGHT,
} from "admin/components/color-palette-editor";
import ThemeSettingEditor from "admin/components/theme-setting-editor";
import ThemeTranslation from "admin/components/theme-translation";
import ThemeUploadAddModal from "admin/components/theme-upload-add";
import ColorSchemeColor from "admin/models/color-scheme-color";
import { THEME_UPLOAD_VAR } from "admin/models/theme";
import ThemeSettings from "admin/models/theme-settings";
import ComboBox from "select-kit/components/combo-box";
import DMenu from "float-kit/components/d-menu";

function substring(string, length) {
  return string.substring(0, length);
}

const MetadataSection = <template>
  <div ...attributes>
    <div class="admin-config-theme__metadata-title">
      {{@title}}
    </div>
    <div class="admin-config-theme__metadata-section">
      {{yield}}
    </div>
  </div>
</template>;

const MetadataLink = <template>
  <a class="admin-config-theme__metadata-link" href={{@href}}>{{@label}}
    {{icon @icon}}</a>
</template>;

export default class AdminConfigAreasTheme extends Component {
  @service siteSettings;
  @service router;
  @service modal;

  @tracked editorMode = LIGHT;
  @tracked editingName = false;
  @tracked selectedLocale;
  @tracked loadingTranslations = false;
  @tracked rawTranslations = this.args.theme.translations;

  @cached
  get data() {
    return {
      name: this.args.theme.name,
      editingName: this.editingName,
      user_selectable: this.args.theme.user_selectable,
      auto_update: this.args.theme.auto_update,
      colors: this.args.theme.color_scheme?.colors.map((c) =>
        ColorSchemeColor.create({ skipChangeTracking: true, ...c })
      ),
    };
  }

  get uploads() {
    const fields = this.args.theme.theme_fields;
    return fields.filter((field) => {
      return field.target === "common" && field.type_id === THEME_UPLOAD_VAR;
    });
  }

  get availableLocales() {
    return JSON.parse(this.siteSettings.available_locales);
  }

  get locale() {
    return this.selectedLocale ?? this.siteSettings.default_locale;
  }

  get translations() {
    return this.rawTranslations.map((t) =>
      ThemeSettings.create({ ...t, textarea: true })
    );
  }

  get sourceIsHttp() {
    return /^http(s)?:\/\//.test(this.args.theme.remote_theme?.remote_url);
  }

  get remoteThemeLink() {
    const url = this.args.theme.remote_theme.remote_url;
    const branch = this.args.theme.remote_theme.branch;

    return branch ? `${url.replace(/\.git$/, "")}/tree/${branch}` : url;
  }

  get editedFieldsFormatted() {
    const descriptions = [];

    ["common", "desktop", "mobile"].forEach((target) => {
      const fields = this.args.theme.editedFields.filter(
        (field) => field.target === target
      );

      if (fields.length < 1) {
        return;
      }

      let resultString = i18n("admin.config_areas.theme." + target);
      const formattedFields = fields
        .map((f) => i18n("admin.config_areas.theme." + f.name))
        .join(" , ");
      resultString += `: ${formattedFields}`;
      descriptions.push(resultString);
    });

    return descriptions;
  }

  get extraFiles() {
    return this.args.theme.theme_fields?.filter((field) => {
      return field.target === "extra_js";
    });
  }

  get availableComponents() {
    const list = [];

    for (const potentialChild of this.args.theme.available_components) {
      if (
        this.args.theme.child_themes?.some(
          (child) => child.id === potentialChild.id
        )
      ) {
        continue;
      }
      list.push(potentialChild);
    }

    return list;
  }

  @action
  toggleEditingName() {
    this.editingName = !this.editingName;
  }

  @action
  async updateLocale(value) {
    this.loadingTranslations = true;
    this.selectedLocale = value;

    try {
      const data = await ajax(
        `/admin/themes/${this.args.theme.id}/translations/${value}`
      );
      this.rawTranslations = data.translations;
      this.args.theme.locale = value;
    } finally {
      this.loadingTranslations = false;
    }
  }

  @action
  onEditorTabSwitch(newMode) {
    this.editorMode = newMode;
  }

  @action
  transitionToEditRoute() {
    this.router.transitionTo(
      "adminConfig.themeEdit",
      this.args.theme.id,
      "common",
      "scss"
    );
  }

  @action
  openUploadModal() {
    this.modal.show(ThemeUploadAddModal, {
      model: {
        themeFields: this.args.theme.theme_fields,
        addUpload: this.addUpload,
      },
    });
  }

  @action
  addUpload(info) {
    const theme = this.args.theme;
    theme.setField("common", info.name, "", info.upload_id, THEME_UPLOAD_VAR);
    theme.saveChanges("theme_fields").catch((e) => popupAjaxError(e));
  }

  <template>
    <Form @data={{this.data}} as |form transientData|>
      <div class="admin-config-area">
        <div class="admin-config-area__primary-content">
          <LinkTo
            class="admin-config-theme__back-link"
            @route="adminConfig.customize.themes"
          >
            {{icon "angle-left"}}
            {{i18n "admin.config_areas.themes_and_components.themes.back"}}
          </LinkTo>
          <div class="admin-config-theme__theme-info">
            <form.Field
              @name="name"
              @showTitle={{false}}
              @title={{i18n "admin.config_areas.color_palettes.palette_name"}}
              @validation="required"
              @format="full"
              @onSet={{this.handleNameChange}}
              as |field|
            >
              {{#if transientData.editingName}}
                <div class="admin-config-theme__name-control">
                  <field.Input />
                  <DButton
                    class="btn-flat"
                    @icon="xmark"
                    @action={{this.toggleEditingName}}
                  />
                  <DButton
                    class="btn-primary"
                    @icon="check"
                    @action={{this.toggleEditingName}}
                  />
                </div>
              {{else}}
                <field.Custom>
                  <div class="admin-config-theme__name-control">
                    <h2>{{@theme.name}}</h2>
                    <DButton
                      class="btn-flat"
                      @icon="pencil"
                      @action={{this.toggleEditingName}}
                    />
                  </div>
                </field.Custom>
              {{/if}}
            </form.Field>

            {{#unless @theme.remote_theme}}
              <div class="admin-config-theme__created-by">
                <span>{{i18n "admin.config_areas.theme.created_by"}}</span>
                <span>
                  <UserLink @user={{@theme.user}}>
                    {{formatUsername @theme.user.username}}
                  </UserLink>
                </span>
              </div>
            {{/unless}}

            {{#if @theme.description}}
              <p
                class="admin-config-theme__description"
              >{{@theme.description}}</p>
            {{/if}}
          </div>

          <AdminConfigAreaCard @heading="admin.config_areas.theme.options">
            <:content>
              <form.Field
                @name="user_selectable"
                @title={{i18n "admin.config_areas.theme.user_selectable"}}
                @showTitle={{false}}
                @description={{i18n "admin.config_areas.theme.user_selectable"}}
                @format="full"
                @onSet={{this.handleUserSelectableChange}}
                as |field|
              >
                <field.Toggle />
              </form.Field>
              <form.Field
                @name="auto_update"
                @title={{i18n "admin.config_areas.theme.auto_update"}}
                @showTitle={{false}}
                @description={{i18n "admin.config_areas.theme.auto_update"}}
                @format="full"
                @onSet={{this.handleUserSelectableChange}}
                as |field|
              >
                <field.Toggle />
              </form.Field>
            </:content>
          </AdminConfigAreaCard>

          {{#if @theme.color_scheme}}
            <AdminConfigAreaCard
              class="admin-config-theme__color-palette-card"
              @heading="admin.config_areas.theme.colors"
              @collapsable={{true}}
            >
              <:content>
                <form.Field
                  @name="colors"
                  @title={{i18n "admin.config_areas.theme.colors"}}
                  @showTitle={{false}}
                  @format="full"
                  as |field|
                >
                  <field.Custom>
                    <ColorPaletteEditor
                      @initialMode={{this.editorMode}}
                      @colors={{transientData.colors}}
                      @onLightColorChange={{this.onLightColorChange}}
                      @onDarkColorChange={{this.onDarkColorChange}}
                      @onTabSwitch={{this.onEditorTabSwitch}}
                    />
                  </field.Custom>
                </form.Field>
              </:content>
            </AdminConfigAreaCard>
          {{/if}}

          <AdminConfigAreaCard
            class="admin-config-theme__components-card"
            @heading="admin.config_areas.theme.components"
            @collapsable={{true}}
            @translatedDescription={{i18n
              "admin.config_areas.theme.components_help"
            }}
          >
            <:content>
              {{#if @theme.child_themes.length}}
                <div class="admin-config-theme__child-components-sections">
                  <div>
                    <span
                      class="admin-config-theme__child-components-heading"
                    >{{i18n "admin.config_areas.theme.included"}}
                      {{icon "minus"}}</span>
                    <DButton
                      @display="link"
                      @label="admin.config_areas.theme.remove_all"
                    />
                    <div class="admin-config-theme__child-components">
                      {{#each @theme.child_themes as |child|}}
                        <div class="admin-config-theme__child-component">
                          <span>{{child.name}}</span>
                          <DButton class="btn-flat" @icon="xmark" />
                        </div>
                      {{/each}}
                    </div>
                  </div>

                  <div>
                    <span
                      class="admin-config-theme__child-components-heading"
                    >{{i18n "admin.config_areas.theme.unused"}}
                      {{icon "minus"}}</span>
                    <DButton
                      @display="link"
                      @label="admin.config_areas.theme.add_all"
                    />
                    <div class="admin-config-theme__child-components">
                      {{#each this.availableComponents as |child|}}
                        <div class="admin-config-theme__child-component">
                          <span>{{child.name}}</span>
                          <DButton class="btn-flat" @icon="plus" />
                        </div>
                      {{/each}}
                    </div>
                  </div>
                </div>
              {{/if}}
            </:content>
          </AdminConfigAreaCard>

          {{#unless @theme.remote_theme.is_git}}
            <AdminConfigAreaCard
              class="admin-config-theme__uploads-card"
              @heading="admin.config_areas.theme.uploads"
              @collapsable={{true}}
            >
              <:headerAction>
                <DButton
                  @action={{this.openUploadModal}}
                  @display="link"
                  @label="admin.config_areas.theme.add_upload"
                />
              </:headerAction>
              <:content>
                {{#if this.uploads.length}}
                  <div class="admin-config-theme__uploads">
                    {{#each this.uploads as |upload|}}
                      <div class="admin-config-theme__upload">
                        {{! template-lint-disable no-unnecessary-curly-strings }}
                        {{! workaround for https://github.com/typed-ember/glint/issues/840 }}
                        <span>{{"$"}}{{upload.name}}:
                          <a
                            href={{upload.url}}
                            rel="noopener noreferrer"
                            target="_blank"
                          >{{upload.filename}}</a>
                        </span>
                        <DButton class="btn-flat" @icon="trash-can" />
                      </div>
                    {{/each}}
                  </div>
                {{else}}
                  <p>{{i18n "admin.config_areas.theme.no_uploads"}}</p>
                {{/if}}
              </:content>
            </AdminConfigAreaCard>
          {{/unless}}

          {{#if @theme.settings.length}}
            <AdminConfigAreaCard
              class="admin-config-theme__settings-card theme settings"
              @heading="admin.config_areas.theme.theme_settings"
              @collapsable={{true}}
              @translatedDescription={{i18n
                "admin.config_areas.theme.theme_settings_help"
              }}
            >
              <:content>
                <div class="admin-config-theme__settings">
                  {{#each @theme.settings as |setting|}}
                    <ThemeSettingEditor
                      @setting={{setting}}
                      @model={{@theme}}
                      class="theme-setting control-unit"
                    />
                  {{/each}}
                </div>
              </:content>
            </AdminConfigAreaCard>
          {{/if}}

          {{#if this.rawTranslations.length}}
            <AdminConfigAreaCard
              class="admin-config-theme__translations-card theme settings translations"
              @heading="admin.config_areas.theme.translations"
              @collapsable={{true}}
            >
              <:headerAction>
                <ComboBox
                  @valueProperty="value"
                  @content={{this.availableLocales}}
                  @value={{this.locale}}
                  @onChange={{this.updateLocale}}
                  @options={{hash filterable=true}}
                />
              </:headerAction>
              <:content>
                <ConditionalLoadingSpinner
                  @condition={{this.loadingTranslations}}
                >
                  <div class="admin-config-theme__translations">
                    {{#each this.translations as |translation|}}
                      <ThemeTranslation
                        @translation={{translation}}
                        @model={{@theme}}
                        class="theme-translation"
                      />
                    {{/each}}
                  </div>
                </ConditionalLoadingSpinner>
              </:content>
            </AdminConfigAreaCard>
          {{/if}}
        </div>

        <div class="admin-config-area__aside">
          <div class="admin-config-theme__top-actions">
            <DButton
              class="btn-primary"
              target="_blank"
              rel="noopener noreferrer"
              @icon="desktop"
              @label="admin.config_areas.theme.preview"
              @href={{getURL (concat "/admin/themes/" @theme.id "/preview")}}
            />
            <DMenu
              @identifier="theme-menu"
              @title={{i18n "admin.config_areas.theme.more"}}
              @label={{i18n "admin.config_areas.theme.more"}}
              @icon="ellipsis"
              @class="btn-default admin-config-theme__more-actions"
            >
              <:content>
                <DropdownMenu as |dropdown|>
                  <dropdown.item>
                    <DButton
                      class="btn-transparent admin-config-theme__export"
                      target="_blank"
                      rel="noopener noreferrer"
                      @label="admin.config_areas.theme.export"
                      @icon="download"
                      @href={{getURL
                        (concat "/admin/customize/themes/" @theme.id "/export")
                      }}
                    />
                  </dropdown.item>
                </DropdownMenu>
              </:content>
            </DMenu>
          </div>
          <div class="admin-config-theme__metadata">
            {{#if @theme.remote_theme}}
              <div class="admin-config-theme__metadata-links">
                {{#if @theme.remote_theme.remote_url}}
                  {{#if this.sourceIsHttp}}
                    <MetadataLink
                      @href={{this.remoteThemeLink}}
                      @icon="link"
                      @label={{i18n "admin.config_areas.theme.source"}}
                    />
                  {{else}}
                    <div class="remote-url">
                      <code>{{@theme.remote_theme.remote_url}}</code>
                      {{#if @theme.remote_theme.branch}}
                        (<code>{{@theme.remote_theme.branch}}</code>)
                      {{/if}}
                    </div>
                  {{/if}}
                {{/if}}

                {{#if @theme.remote_theme.about_url}}
                  <MetadataLink
                    @href={{@theme.remote_theme.about_url}}
                    @icon="link"
                    @label={{i18n "admin.config_areas.theme.about"}}
                  />
                {{/if}}

                {{#if @theme.remote_theme.license_url}}
                  <MetadataLink
                    @href={{@theme.remote_theme.license_url}}
                    @icon="link"
                    @label={{i18n "admin.config_areas.theme.license"}}
                  />
                {{/if}}
              </div>
            {{/if}}

            {{#if @theme.remote_theme.theme_version}}
              <MetadataSection
                @title={{i18n "admin.config_areas.theme.version"}}
              >
                {{@theme.remote_theme.theme_version}}
              </MetadataSection>
            {{/if}}
            {{#if @theme.remote_theme}}
              <MetadataSection
                class="admin-config-theme__last-updated"
                @title={{i18n "admin.config_areas.theme.last_updated"}}
              >
                <span>{{formatDate
                    @theme.remote_theme.updated_at
                    leaveAgo="true"
                  }}
                  {{#if @theme.remote_theme.local_version}}
                    (<span class="admin-config-theme__sha">{{substring
                        @theme.remote_theme.local_version
                        6
                      }}</span>){{/if}}</span>
                <DButton
                  class="btn-flat admin-config-theme__check-for-update"
                  @icon="arrows-rotate"
                />
              </MetadataSection>

              <MetadataSection
                @title={{i18n "admin.config_areas.theme.theme_storage"}}
              >
                {{icon "cloud-arrow-up"}}
                {{i18n "admin.config_areas.theme.remote_theme"}}
              </MetadataSection>

            {{/if}}

            {{#unless @theme.remote_theme.is_git}}
              {{#if @theme.hasEditedFields}}
                <MetadataSection
                  @title={{i18n "admin.config_areas.theme.custom_css_html"}}
                >
                  <ul class="admin-config-theme__custom-css-html">
                    {{#each this.editedFieldsFormatted as |field|}}
                      <li>{{field}}</li>
                    {{/each}}
                  </ul>
                  <DButton
                    @action={{this.transitionToEditRoute}}
                    @display="link"
                    @label="admin.config_areas.theme.edit_css_html"
                  />
                </MetadataSection>
              {{/if}}
            {{/unless}}

            {{#if this.extraFiles.length}}
              <MetadataSection
                @title={{i18n "admin.config_areas.theme.extra_files"}}
              >
                <details>
                  <summary>
                    {{#if @theme.remote_theme}}
                      {{i18n "admin.config_areas.theme.extra_files_remote"}}
                    {{else}}
                      {{i18n "admin.config_areas.theme.extra_files_upload"}}
                    {{/if}}
                  </summary>
                  <ul>
                    {{#each this.extraFiles as |extraFile|}}
                      <li>{{extraFile.name}}</li>
                    {{/each}}
                  </ul>
                </details>
              </MetadataSection>
            {{/if}}
          </div>
        </div>
      </div>
    </Form>
  </template>
}
