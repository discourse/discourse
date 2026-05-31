import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { trustHTML } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

// Human labels for the system color tokens (these annotate the d-system.* token
// rows; they are not display strings the admin edits).
const LABELS = {
  "surface.default": "Background",
  "surface.sunken": "Sunken background",
  "surface.raised": "Raised background",
  "surface.hovered": "Hovered background",
  "surface.selected": "Selected background",
  "surface.brand": "Brand background",
  "surface.brand-hovered": "Brand background hovered",
  "surface.danger": "Danger background",
  "surface.success": "Success background",
  "text.default": "Default text",
  "text.subtle": "Subtle text",
  "text.inverse": "Inverse text",
  "text.brand": "Brand text",
  "text.danger": "Danger text",
  "text.success": "Success text",
  "text.link": "Link",
  "text.link-hover": "Link hovered",
  "border.default": "Default border",
  "border.bold": "Bold border",
  "border.subtle": "Subtle border",
  "border.brand": "Brand border",
  "border.danger": "Danger border",
  "interactive.default": "Interactive",
  "interactive.hovered": "Interactive hovered",
  "interactive.pressed": "Interactive pressed",
};

const DARK = "com.discourse.dark";

function flattenTokens(node, path = []) {
  const results = [];
  for (const [key, value] of Object.entries(node)) {
    if (key.startsWith("$")) {
      continue;
    }
    const currentPath = [...path, key];
    if (value && typeof value === "object" && "$value" in value) {
      results.push({
        path: currentPath,
        value: value.$value,
        darkValue: value.$extensions?.[DARK],
      });
    } else if (value && typeof value === "object") {
      results.push(...flattenTokens(value, currentPath));
    }
  }
  return results;
}

// Group the system color tokens by the segment after "color"
// (surface / text / border / interactive).
function buildGroups(dtcg) {
  const groups = {};
  for (const token of flattenTokens(dtcg)) {
    const colorIdx = token.path.indexOf("color");
    if (colorIdx === -1) {
      continue;
    }
    const groupName = token.path[colorIdx + 1];
    const tokenName = token.path.slice(colorIdx + 2).join(".");
    (groups[groupName] ||= []).push({
      label: LABELS[`${groupName}.${tokenName}`] || tokenName,
      value: token.value,
      darkValue: token.darkValue,
      tokenPath: token.path.join("."),
    });
  }
  return Object.entries(groups).map(([name, tokens]) => ({
    name,
    label: name.charAt(0).toUpperCase() + name.slice(1),
    tokens,
  }));
}

export default class DesignSystemColorEditor extends Component {
  @tracked groups = [];
  @tracked loading = true;

  constructor() {
    super(...arguments);
    this.load();
  }

  async load() {
    try {
      const result = await ajax("/admin/config/design-system/colors/data");
      this.groups = buildGroups(JSON.parse(result.content));
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  <template>
    {{#each this.groups as |group|}}
      <section class="design-system-editor__group">
        <h3 class="design-system-editor__group-title">{{group.label}}</h3>
        <div class="design-system-editor__head">
          <span class="design-system-editor__name"></span>
          <span class="design-system-editor__col">
            {{i18n "admin.config.design_system.light"}}
          </span>
          <span class="design-system-editor__col">
            {{i18n "admin.config.design_system.dark"}}
          </span>
        </div>
        {{#each group.tokens as |token|}}
          <div class="design-system-editor__row">
            <span class="design-system-editor__name">{{token.label}}</span>
            <span class="design-system-editor__cell">
              <span
                class="design-system-editor__swatch"
                style={{trustHTML (concat "background-color:" token.value)}}
              ></span>
              <span class="design-system-editor__value">{{token.value}}</span>
            </span>
            <span class="design-system-editor__cell">
              {{#if token.darkValue}}
                <span
                  class="design-system-editor__swatch"
                  style={{trustHTML
                    (concat "background-color:" token.darkValue)
                  }}
                ></span>
                <span
                  class="design-system-editor__value"
                >{{token.darkValue}}</span>
              {{/if}}
            </span>
            <code class="design-system-editor__path">{{token.tokenPath}}</code>
          </div>
        {{/each}}
      </section>
    {{/each}}
  </template>
}
