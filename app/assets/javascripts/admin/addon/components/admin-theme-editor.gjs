import { tracked } from "@glimmer/tracking";
import Component, { Input } from "@ember/component";
import { array, concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, computed } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { gt, lte } from "truth-helpers";
import AceEditor from "discourse/components/ace-editor";
import icon from "discourse/helpers/d-icon";
import htmlSafe from "discourse/helpers/html-safe";
import { fmt } from "discourse/lib/computed";
import discourseComputed from "discourse/lib/decorators";
import { isDocumentRTL } from "discourse/lib/text-direction";
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

export default class AdminThemeEditor extends Component {
  @service router;

  @tracked showAdvanced;
  @tracked onlyOverridden;
  @tracked currentTargetName;

  warning = null;

  @fmt("fieldName", "currentTargetName", "%@|%@") editorId;

  get visibleTargets() {
    return this.theme.targets.filter((target) => {
      if (target.edited) {
        return true;
      }
      if (!this.showAdvanced && ADVANCED_TARGETS.includes(target.name)) {
        return false;
      }
      if (!this.onlyOverridden) {
        return true;
      }
    });
  }

  get visibleFields() {
    let fields = this.theme.fields[this.currentTargetName];
    if (this.onlyOverridden) {
      fields = fields.filter((field) => field.edited);
    }
    if (!this.showAdvanced) {
      fields = fields.filter(
        (field) => field.edited || !ADVANCED_FIELDS.includes(field.name)
      );
    }
    return fields;
  }

  get currentField() {
    return this.theme.fields[this.currentTargetName].find(
      (field) => field.name === this.fieldName
    );
  }

  @discourseComputed("currentTargetName", "fieldName")
  activeSectionMode(targetName, fieldName) {
    if (fieldName === "color_definitions") {
      return "scss";
    }
    if (fieldName === "js") {
      return "javascript";
    }
    return fieldName && fieldName.includes("scss") ? "scss" : "html";
  }

  @discourseComputed("currentTargetName", "fieldName")
  placeholder(targetName, fieldName) {
    if (fieldName && fieldName === "color_definitions") {
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

  @discourseComputed("maximized")
  maximizeIcon(maximized) {
    return maximized ? "discourse-compress" : "discourse-expand";
  }

  @discourseComputed(
    "currentTargetName",
    "fieldName",
    "theme.theme_fields.@each.error"
  )
  error(target, fieldName) {
    return this.theme.getError(target, fieldName);
  }

  @action
  toggleMaximize(event) {
    event?.preventDefault();
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
    {{#if (gt this.visibleTargets.length 1)}}
      <div class="edit-main-nav admin-controls">
        <nav>
          <ul class="nav nav-pills target">
            {{#each this.visibleTargets as |target|}}
              <li>
                <LinkTo
                  @route={{this.editRouteName}}
                  @models={{array this.theme.id target.name this.fieldName}}
                  @replace={{true}}
                  title={{this.field.title}}
                  class={{if target.edited "edited" "blank"}}
                >
                  {{#if target.error}}{{icon "triangle-exclamation"}}{{/if}}
                  {{#if target.icon}}{{icon target.icon}}{{/if}}
                  {{i18n (concat "admin.customize.theme." target.name)}}
                </LinkTo>
              </li>
            {{/each}}
            <li class="spacer"></li>
            <li>
              <label>
                <Input
                  @type="checkbox"
                  @checked={{this.showAdvanced}}
                  {{on "click" this.toggleShowAdvanced}}
                />
                {{i18n "admin.customize.theme.show_advanced"}}
              </label>
            </li>
          </ul>
        </nav>
      </div>
    {{/if}}

    <div class="admin-controls">
      <nav>
        <ul class="nav nav-pills fields">
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
                {{#if field.error}}{{icon "triangle-exclamation"}}{{/if}}
                {{#if field.icon}}{{icon field.icon}}{{/if}}
                {{field.translatedName}}
              </LinkTo>
            </li>
          {{/each}}

          <li class="spacer"></li>
          <li>
            {{#if (lte this.visibleTargets.length 1)}}
              <label>
                <Input
                  @type="checkbox"
                  @checked={{this.showAdvanced}}
                  {{on "click" this.toggleShowAdvanced}}
                />
                {{i18n "admin.customize.theme.show_advanced"}}
              </label>
            {{/if}}
            <a href {{on "click" this.toggleMaximize}} class="no-text">
              {{icon this.maximizeIcon}}
            </a>
          </li>
        </ul>
      </nav>
    </div>

    {{#if this.error}}
      <pre class="field-error">{{this.error}}</pre>
    {{/if}}

    {{#if this.warning}}
      <pre class="field-warning">{{htmlSafe this.warning}}</pre>
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
  </template>
}
