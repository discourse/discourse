import Component from "@ember/component";
import { action, computed } from "@ember/object";
import { next } from "@ember/runloop";
import { fmt } from "discourse/lib/computed";
import discourseComputed from "discourse/lib/decorators";
import { isDocumentRTL } from "discourse/lib/text-direction";
import { i18n } from "discourse-i18n";

const JS_DEFAULT_VALUE = `import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  // Your code here
});
`;

export default class AdminThemeEditor extends Component {
  warning = null;

  @fmt("fieldName", "currentTargetName", "%@|%@") editorId;

  @discourseComputed("theme.targets", "onlyOverridden")
  visibleTargets(targets, onlyOverridden) {
    return targets.filter((target) => {
      if (!onlyOverridden) {
        return true;
      }
      return target.edited;
    });
  }

  @discourseComputed("currentTargetName", "onlyOverridden", "theme.fields")
  visibleFields(targetName, onlyOverridden, fields) {
    fields = fields[targetName];
    if (onlyOverridden) {
      fields = fields.filter((field) => field.edited);
    }
    return fields;
  }

  @discourseComputed("currentTargetName", "fieldName")
  activeSectionMode(targetName, fieldName) {
    if (["color_definitions"].includes(fieldName)) {
      return "scss";
    }
    if (["js"].includes(fieldName)) {
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
}
