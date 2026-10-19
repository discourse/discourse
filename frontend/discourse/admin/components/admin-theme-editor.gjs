/* eslint-disable ember/no-classic-components */
import { tracked } from "@glimmer/tracking";
import Component from "@ember/component";
import { array, concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, computed } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { tagName } from "@ember-decorators/component";
import AceEditor from "discourse/components/ace-editor";
import { isDocumentRTL } from "discourse/lib/text-direction";
import { gt } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const JS_DEFAULT_VALUE = `import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  // Your code here
});
`;

const ADVANCED_TARGETS = ["desktop", "mobile"];
const EMAIL_TARGETS = ["email_header", "email_footer"];

const ADVANCED_FIELDS = [
  "embedded_scss",
  "embedded_header",
  "color_definitions",
  "body_tag",
];

@tagName("")
export default class AdminThemeEditor extends Component {
  @service router;
  @service siteSettings;

  @tracked showAdvanced;
  currentTargetName;

  /** @type {string | false | null} */
  warning = null;

  @computed("fieldName", "currentTargetName", "theme")
  get activeSection() {
    const themeValue = this.theme.getField(
      this.currentTargetName,
      this.fieldName
    );
    if (!themeValue && this.fieldName === "js") {
      return JS_DEFAULT_VALUE;
    }
    return themeValue;
  }

  set activeSection(value) {
    if (this.fieldName === "js" && value === JS_DEFAULT_VALUE) {
      value = "";
    }
    this.theme.setField(this.currentTargetName, this.fieldName, value);
  }

  @computed("fieldName", "currentTargetName")
  get editorId() {
    return `${this.fieldName}|${this.currentTargetName}`;
  }

  @computed("currentTargetName", "showAdvanced")
  get advancedModeEnabled() {
    return this.showAdvanced || EMAIL_TARGETS.includes(this.currentTargetName);
  }

  get emailFieldsDisabled() {
    return !this.siteSettings.enable_email_theme_header_and_footer;
  }

  @computed("currentTargetName")
  get emailEditorDisabled() {
    return (
      this.emailFieldsDisabled && EMAIL_TARGETS.includes(this.currentTargetName)
    );
  }

  @computed("currentTargetName")
  get navigationTargetName() {
    return EMAIL_TARGETS.includes(this.currentTargetName)
      ? "common"
      : this.currentTargetName;
  }

  @computed("currentTargetName", "fieldName", "showAdvanced", "theme.fields")
  get navigationFieldName() {
    return EMAIL_TARGETS.includes(this.currentTargetName)
      ? this.visibleFields[0].name
      : this.fieldName;
  }

  get visibleTargets() {
    return this.theme.targets.filter((target) => {
      if (EMAIL_TARGETS.includes(target.name)) {
        return false;
      }
      if (target.edited) {
        return true;
      }
      if (!this.advancedModeEnabled && ADVANCED_TARGETS.includes(target.name)) {
        return false;
      }
      return true;
    });
  }

  @computed("currentTargetName", "showAdvanced", "theme.fields")
  get visibleFields() {
    let fields = this.theme.fields[this.navigationTargetName];
    if (!this.advancedModeEnabled) {
      fields = fields.filter(
        (field) => field.edited || !ADVANCED_FIELDS.includes(field.name)
      );
    }
    return fields;
  }

  @computed("currentTargetName", "showAdvanced", "theme.fields")
  get visibleEmailFields() {
    if (!this.advancedModeEnabled) {
      return [];
    }

    return EMAIL_TARGETS.flatMap((targetName) =>
      this.theme.fields[targetName].map((field) => ({ ...field, targetName }))
    );
  }

  @computed("currentTargetName", "fieldName", "theme.fields")
  get currentField() {
    return this.theme.fields[this.currentTargetName].find(
      (field) => field.name === this.fieldName
    );
  }

  @computed("currentTargetName", "fieldName")
  get activeSectionMode() {
    if (this.fieldName === "color_definitions") {
      return "scss";
    }
    if (this.fieldName === "js") {
      return "javascript";
    }
    return this.fieldName && this.fieldName.includes("scss") ? "scss" : "html";
  }

  @computed("currentTargetName", "fieldName")
  get placeholder() {
    if (this.fieldName && this.fieldName === "color_definitions") {
      const example =
        ":root {\n" +
        "  --mytheme-tertiary-or-highlight: #{dark-light-choose($tertiary, $highlight)};\n" +
        "}";

      return i18n("admin.customize.theme.color_definitions.placeholder", {
        example: isDocumentRTL() ? `<div dir="ltr">${example}</div>` : example,
      });
    }
    return "";
  }

  @computed("maximized")
  get maximizeIcon() {
    return this.maximized ? "discourse-compress" : "discourse-expand";
  }

  @computed("maximized")
  get maximizeTitle() {
    return this.maximized
      ? "admin.customize.theme.minimize_editor"
      : "admin.customize.theme.maximize_editor";
  }

  @computed("currentTargetName", "fieldName", "theme.theme_fields.@each.error")
  get error() {
    return this.theme.getError(this.currentTargetName, this.fieldName);
  }

  @action
  toggleMaximize() {
    this.toggleProperty("maximized");
    next(() => this.appEvents.trigger("ace:resize"));
  }

  @action
  setWarning(message) {
    this.set("warning", message);
  }

  @action
  toggleShowAdvanced() {
    this.showAdvanced = !this.advancedModeEnabled;
    this.onShowAdvancedChange(this.showAdvanced);

    if (!this.showAdvanced && EMAIL_TARGETS.includes(this.currentTargetName)) {
      this.router.replaceWith(
        this.editRouteName,
        this.theme.id,
        this.visibleTargets[0].name,
        this.visibleFields[0].name
      );
      return;
    }

    if (
      !this.visibleTargets.some(
        (target) => target.name === this.currentTargetName
      ) ||
      !this.visibleFields.some((field) => field.name === this.fieldName)
    ) {
      this.router.replaceWith(
        this.editRouteName,
        this.theme.id,
        this.visibleTargets[0].name,
        this.visibleFields[0].name
      );
    }
  }

  <template>
    <div ...attributes>
      <div class="editor-information">
        <div class="editor-information__title">
          <DButton
            class="btn-default btn-small editor-back-button"
            @action={{this.goBack}}
            @icon="chevron-left"
            @title="go_back"
          />

          <span class="editor-theme-name-wrapper">
            {{i18n "admin.customize.theme.edit_css_html"}}
            <LinkTo
              class="editor-theme-name"
              @model={{this.theme.id}}
              @replace={{true}}
              @route={{this.showRouteName}}
            >
              {{this.theme.name}}
            </LinkTo>
          </span>
        </div>

        <div class="editor-information__admin-actions">
          <DToggleSwitch
            @label="admin.customize.theme.show_advanced"
            @state={{this.advancedModeEnabled}}
            {{on "click" this.toggleShowAdvanced}}
          />

          <DButton
            class="btn-transparent theme-editor-maximize"
            @action={{this.toggleMaximize}}
            @icon={{this.maximizeIcon}}
            @title={{this.maximizeTitle}}
          />
        </div>
      </div>

      {{#if (gt this.visibleTargets.length 1)}}
        <div class="edit-main-nav admin-controls">
          <DHorizontalOverflowNav @className="target">
            {{#each this.visibleTargets as |target|}}
              <li>
                <LinkTo
                  class={{if target.edited "edited" "blank"}}
                  title={{this.field.title}}
                  @models={{array
                    this.theme.id
                    target.name
                    this.navigationFieldName
                  }}
                  @replace={{true}}
                  @route={{this.editRouteName}}
                >
                  {{#if target.error}}{{dIcon "triangle-exclamation"}}{{/if}}
                  {{#if target.icon}}{{dIcon target.icon}}{{/if}}
                  {{#if target.translatedName}}
                    {{target.translatedName}}
                  {{else}}
                    {{i18n (concat "admin.customize.theme." target.name)}}
                  {{/if}}
                </LinkTo>
              </li>
            {{/each}}
          </DHorizontalOverflowNav>
        </div>
      {{/if}}

      <div class="admin-controls theme-editor__fields">
        <DHorizontalOverflowNav @className="fields">
          {{#each this.visibleFields as |field|}}
            <li>
              <LinkTo
                class={{if field.edited "edited" "blank"}}
                title={{field.title}}
                @models={{array
                  this.theme.id
                  this.navigationTargetName
                  field.name
                }}
                @replace={{true}}
                @route={{this.editRouteName}}
              >
                {{#if field.error}}{{dIcon "triangle-exclamation"}}{{/if}}
                {{#if field.icon}}{{dIcon field.icon}}{{/if}}
                {{field.translatedName}}
              </LinkTo>
            </li>
          {{/each}}
        </DHorizontalOverflowNav>
      </div>

      {{#if this.visibleEmailFields.length}}
        <div
          class={{dConcatClass
            "admin-controls"
            "theme-editor__advanced-fields"
            (if this.emailFieldsDisabled "is-disabled")
          }}
        >
          <DHorizontalOverflowNav @className="advanced-fields">
            {{#each this.visibleEmailFields as |field|}}
              <li>
                <LinkTo
                  class={{if field.edited "edited" "blank"}}
                  title={{field.title}}
                  @models={{array this.theme.id field.targetName field.name}}
                  @replace={{true}}
                  @route={{this.editRouteName}}
                >
                  {{#if field.error}}{{dIcon "triangle-exclamation"}}{{/if}}
                  {{field.translatedName}}
                </LinkTo>
              </li>
            {{/each}}
          </DHorizontalOverflowNav>
        </div>

        {{#if this.emailFieldsDisabled}}
          <div
            class="theme-editor__email-disabled-notice alert alert-warning"
            id="theme-email-fields-disabled-notice"
          >
            {{dIcon "triangle-exclamation"}}
            <span>
              {{i18n "admin.customize.theme.email_theme_fields_disabled"}}
            </span>
          </div>
        {{/if}}
      {{/if}}
      {{#if this.error}}
        <pre class="field-error">{{this.error}}</pre>
      {{/if}}

      {{#if this.warning}}
        <pre class="field-warning">{{trustHTML this.warning}}</pre>
      {{/if}}

      <div class="field-info">
        {{this.currentField.title}}
      </div>

      {{#each (array this.editorId) key="@identity" as |editorId|}}
        <AceEditor
          aria-describedby={{if
            this.emailEditorDisabled
            "theme-email-fields-disabled-notice"
          }}
          aria-readonly={{if this.emailEditorDisabled "true" "false"}}
          class={{dConcatClass
            "theme-editor__code"
            (if this.emailEditorDisabled "is-disabled")
          }}
          @autofocus="true"
          @content={{this.activeSection}}
          @disabled={{this.emailEditorDisabled}}
          @editorId={{editorId}}
          @htmlPlaceholder={{true}}
          @mode={{this.activeSectionMode}}
          @onChange={{fn (mut this.activeSection)}}
          @placeholder={{this.placeholder}}
          @save={{this.save}}
          @setWarning={{this.setWarning}}
        />
      {{/each}}
    </div>
  </template>
}
