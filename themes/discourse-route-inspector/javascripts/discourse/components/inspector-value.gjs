import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import concatClass from "discourse/helpers/concat-class";
import { getValueType } from "../lib/get-value-type";
import { highlightText } from "../lib/highlight-text";
import CopyButton from "./copy-button";

export default class InspectorValue extends Component {
  @tracked isExpanded = false;
  @tracked isTruncated = false;
  codeElement = null;

  @action
  onClick() {
    if (this.canDrillInto) {
      this.args.onDrillInto?.();
    }
  }

  @action
  setupTruncationDetection(element) {
    this.codeElement = element;
    this.checkTruncation();
  }

  @action
  checkTruncation() {
    if (!this.codeElement || this.shouldShowFullValue) {
      this.isTruncated = false;
      return;
    }


    this.isTruncated =
      this.codeElement.scrollHeight > this.codeElement.clientHeight ||
      this.codeElement.scrollWidth > this.codeElement.clientWidth;
  }

  get canDrillInto() {
    const value = this.args.value;
    if (this.isTruncated) {
      return true;
    }
    if (Array.isArray(value) && value.length > 0) {
      return true;
    }
    if (
      typeof value === "object" &&
      value !== null &&
      Object.keys(value).length > 0
    ) {
      return true;
    }
    return false;
  }

  get type() {
    return getValueType(this.args.value);
  }

  get isSimpleValue() {
    return this.type !== "array" && this.type !== "object";
  }

  get shouldShowFullValue() {
    // In simple detail view (viewing a single simple value), show full value
    return this.args.isSimpleDetailsView && this.isSimpleValue;
  }

  get formattedValue() {
    const val = this.args.value;
    if (this.type === "string") {
      return `"${val}"`;
    }
    if (this.type === "function") {
      return "function";
    }
    if (this.type === "param") {
      // Format as key="value", key2="value2"
      const data = val._data;
      return Object.entries(data)
        .map(([k, v]) => `${k}="${v}"`)
        .join(", ");
    }
    if (this.type === "object") {
      const preview = Object.entries(val)
        .sort(([k1], [k2]) => {
          const isInternal1 = k1.startsWith("_");
          const isInternal2 = k2.startsWith("_");
          if (isInternal1 && !isInternal2) {
            return 1;
          }
          if (!isInternal1 && isInternal2) {
            return -1;
          }
          return k1.localeCompare(k2);
        })
        .slice(0, 3)
        .map(([k, v]) => `${k}: ${this.formatPreview(v)}`)
        .join(", ");
      return `{${preview}${Object.keys(val).length > 3 ? ", ..." : ""}}`;
    }
    if (this.type === "array") {
      const preview = val
        .slice(0, 3)
        .map((v) => this.formatPreview(v))
        .join(", ");
      return `[${preview}${val.length > 3 ? `, +${val.length - 3}` : ""}]`;
    }
    return String(val);
  }

  get decoratedValue() {
    return highlightText(this.formattedValue, this.args.filter);
  }

  formatPreview(value) {
    if (typeof value === "string") {
      return `"${value.slice(0, 20)}"`;
    }
    if (typeof value === "number") {
      return String(value);
    }
    if (value === null) {
      return "null";
    }
    if (typeof value === "object") {
      if (value.name) {
        return `{${value.name}}`;
      }
      if (value.id) {
        return `{${value.id}}`;
      }
      return `{object}`;
    }
    return typeof value;
  }

  safeStringify(value) {
  const seen = new WeakSet();

  return JSON.stringify(value, (key, val) => {
    if (typeof val === "object" && val !== null) {
      if (seen.has(val)) {
        return `<Circular reference: ${key}>`;
      }
      seen.add(val);
    }
    return val;
  });
}

  get formatForClipboard() {
    const value = this.args.value;
    console.log("Formatting value for clipboard:", value);
    console.log("Value type:", typeof value);
    if (typeof value === "string") {
      return value;
    }
    if (typeof value === "number") {
      return String(value);
    }
    if (value === null) {
      return "null";
    }
    if (Array.isArray(value)) {
      let result;
      try {
        result =  this.safeStringify(value);
      } catch(error) {
        result `[array]`;
      }
      return result;
    }
    if (typeof value === "object") {
      let result;
      try {
        result =  this.safeStringify(value);
      } catch(error) {
        console.error("Error formatting object for clipboard:", error);
        result =`{object}`;
      }
      return result;
    }
    return value;
  }

  get canCopy() {
    const val = this.args.value;
    if (val === null || val === undefined) {
      return false;
    }
    if (this.type === "param") {
      return true;
    }
    if (this.type === "array") {
      return val.length > 0;
    }
    if (this.type === "object") {
      return Object.keys(val).length > 0;
    }
    return true;
  }

  get isEmpty() {
    const val = this.args.value;
    if (this.type === "array" && val.length === 0) {
      return true;
    }
    if (this.type === "object" && Object.keys(val).length === 0) {
      return true;
    }
    return false;
  }

  <template>
    <div
      class={{concatClass
        "inspector-value"
        (concat "--type-" this.type)
        (if this.isEmpty "--empty")
        "inspector-data-table__hoverable-cell"
      }}
    >
      {{#if this.shouldShowFullValue}}
        <code
          class="inspector-value__code --full-value"
          {{didInsert this.setupTruncationDetection}}
          {{didUpdate this.checkTruncation this.formattedValue}}
        >
          {{this.decoratedValue}}
        </code>
      {{else}}
        <code
          class={{concatClass
            "inspector-value__code"
            (if this.canDrillInto "--drillable")
          }}
          role="button"
          tabindex="0"
          {{on "click" this.onClick}}
          {{didInsert this.setupTruncationDetection}}
          {{didUpdate this.checkTruncation this.formattedValue}}
        >
          {{this.decoratedValue}}
        </code>
      {{/if}}
      <div class="inspector-value__actions">
        {{#if this.canCopy}}
          <CopyButton @value={{this.formatForClipboard}} />
        {{/if}}
      </div>
    </div>
  </template>
}
