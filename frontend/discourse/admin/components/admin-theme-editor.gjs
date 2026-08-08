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
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const JS_DEFAULT_VALUE = `import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  // Your code here
});
`;

const ADVANCED_TARGETS = ["desktop", "mobile"];

const ADVANCED_FIELDS = [
  "embedded_scss",
  "embedded_header",
  "color_definitions",
  "body_tag",
];

@tagName("")
export default class AdminThemeEditor extends Component {
  @service router;

  @tracked showAdvanced;
  currentTargetName;

  warning = null;

  @computed("fieldName", "currentTargetName")
  get editorId() {
    return `${this.fieldName}|${this.currentTargetName}`;
  }

  get visibleTargets() {
    return this.theme.targets.filter((target) => {
      if (target.edited) {
        return true;
      }
      if (!this.showAdvanced && ADVANCED_TARGETS.includes(target.name)) {
        return false;
      }
      return true;
    });
  }

  @computed("currentTargetName", "showAdvanced", "theme.fields")
  get visibleFields() {
    let fields = this.theme.fields[this.currentTargetName];
    if (!this.showAdvanced) {
      fields = fields.filter(
        (field) => field.edited || !ADVANCED_FIELDS.includes(field.name)
      );
    }
    return fields;
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
    this.showAdvanced = !this.showAdvanced;
    if (
      !this.visibleTargets.some((t) => t.name === this.currentTargetName) ||
      !this.visibleFields.some((f) => f.name === this.fieldName)
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
            @title="go_back"
            @action={{this.goBack}}
            @icon="chevron-left"
            class="btn-default btn-small editor-back-button"
          />

          <span class="editor-theme-name-wrapper">
            {{i18n "admin.customize.theme.edit_css_html"}}
            <LinkTo
              @route={{this.showRouteName}}
              @model={{this.theme.id}}
              @replace={{true}}
              class="editor-theme-name"
            >
              {{this.theme.name}}
            </LinkTo>
          </span>
        </div>

        <div class="editor-information__admin-actions">
          <DToggleSwitch
            @state={{this.showAdvanced}}
            @label="admin.customize.theme.show_advanced"
            {{on "click" this.toggleShowAdvanced}}
          />

          <DButton
            @action={{this.toggleMaximize}}
            @icon={{this.maximizeIcon}}
            @title={{this.maximizeTitle}}
            class="btn-transparent theme-editor-maximize"
          />
        </div>
      </div>

      {{#if (gt this.visibleTargets.length 1)}}
        <div class="edit-main-nav admin-controls">
          <DHorizontalOverflowNav @className="target">
            {{#each this.visibleTargets as |target|}}
              <li>
                <LinkTo
                  @route={{this.editRouteName}}
                  @models={{array this.theme.id target.name this.fieldName}}
                  @replace={{true}}
                  title={{this.field.title}}
                  class={{if target.edited "edited" "blank"}}
                >
                  {{#if target.error}}{{dIcon "triangle-exclamation"}}{{/if}}
                  {{#if target.icon}}{{dIcon target.icon}}{{/if}}
                  {{i18n (concat "admin.customize.theme." target.name)}}
                </LinkTo>
              </li>
            {{/each}}
          </DHorizontalOverflowNav>
        </div>
      {{/if}}

      <div class="admin-controls">
        <DHorizontalOverflowNav @className="fields">
          {{#each this.visibleFields as |field|}}
            <li>
              <LinkTo
                @route={{this.editRouteName}}
                @models={{array
                  this.theme.id
                  this.currentTargetName
                  field.name
                }}
                @replace={{true}}
                title={{field.title}}
                class={{if field.edited "edited" "blank"}}
              >
                {{#if field.error}}{{dIcon "triangle-exclamation"}}{{/if}}
                {{#if field.icon}}{{dIcon field.icon}}{{/if}}
                {{field.translatedName}}
              </LinkTo>
            </li>
          {{/each}}
        </DHorizontalOverflowNav>
      </div>

      {{#if this.error}}
        <pre class="field-error">{{this.error}}</pre>
      {{/if}}

      {{#if this.warning}}
        <pre class="field-warning">{{trustHTML this.warning}}</pre>
      {{/if}}

      <div class="field-info">
        {{this.currentField.title}}
      </div>

      <AceEditor
        @content={{this.activeSection}}
        @onChange={{fn (mut this.activeSection)}}
        @editorId={{this.editorId}}
        @mode={{this.activeSectionMode}}
        @autofocus="true"
        @placeholder={{this.placeholder}}
        @htmlPlaceholder={{true}}
        @save={{this.save}}
        @setWarning={{this.setWarning}}
      />
    </div>
  </template>
}
