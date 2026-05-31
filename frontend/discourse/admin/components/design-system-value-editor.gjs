import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

// Generic editor for the non-color (value-only, mode-independent) system token
// tabs — fonts and layout. Pass @fileName ("fonts" | "layout").

function flattenTokens(node, path = []) {
  const results = [];
  for (const [key, value] of Object.entries(node)) {
    if (key.startsWith("$")) {
      continue;
    }
    const currentPath = [...path, key];
    if (value && typeof value === "object" && "$value" in value) {
      results.push({ path: currentPath, value: value.$value });
    } else if (value && typeof value === "object") {
      results.push(...flattenTokens(value, currentPath));
    }
  }
  return results;
}

function titleize(key) {
  const text = String(key).replace(/-/g, " ");
  return text.charAt(0).toUpperCase() + text.slice(1);
}

// Group tokens by their leaf's parent segment (e.g. font.size.caption -> "Size",
// space.gap.xs -> "Gap", radius.default -> "Radius").
function buildGroups(dtcg) {
  const groups = {};
  for (const token of flattenTokens(dtcg)) {
    const groupKey = token.path[token.path.length - 2];
    (groups[groupKey] ||= []).push({
      label: titleize(token.path[token.path.length - 1]),
      value: token.value,
      tokenPath: token.path.join("."),
    });
  }
  return Object.entries(groups).map(([name, tokens]) => ({
    label: titleize(name),
    tokens,
  }));
}

export default class DesignSystemValueEditor extends Component {
  @tracked groups = [];
  @tracked loading = true;

  constructor() {
    super(...arguments);
    this.load();
  }

  async load() {
    try {
      const result = await ajax(
        `/admin/config/design-system/${this.args.fileName}/data`
      );
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
        {{#each group.tokens as |token|}}
          <div class="design-system-editor__row">
            <span class="design-system-editor__name">{{token.label}}</span>
            <span class="design-system-editor__value">{{token.value}}</span>
            <code class="design-system-editor__path">{{token.tokenPath}}</code>
          </div>
        {{/each}}
      </section>
    {{/each}}
  </template>
}
