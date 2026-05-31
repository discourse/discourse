// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { VALID_PAGE_TYPES } from "discourse/lib/blocks/-internals/matching/page-definitions";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

/**
 * Context-sensitive editor for the `route` condition. The route
 * condition evaluates pages (semantic page-type checks), URL patterns
 * (glob matching), and optional params / queryParams shape checks.
 *
 * The UI prioritises the common case — pick one or more page types —
 * over the advanced case (glob patterns, params). Pattern editing
 * lives behind an `Advanced` disclosure so the default surface stays
 * focused.
 *
 * Schema:
 *  - `pages` — array of `VALID_PAGE_TYPES` ids
 *  - `urls` — array of glob patterns (one per line in the textarea)
 *  - `params` / `queryParams` — JSON objects, edited via the
 *     disclosure as raw JSON. A structured editor would need access
 *     to the page-type's params schema.
 */
const PAGE_LABELS = {
  HOMEPAGE: "homepage",
  TOP_MENU: "top_menu",
  TOPIC_PAGES: "topic_pages",
  CATEGORY_PAGES: "category_pages",
  TAG_PAGES: "tag_pages",
  DISCOVERY_PAGES: "discovery_pages",
  USER_PAGES: "user_pages",
  ADMIN_PAGES: "admin_pages",
  GROUP_PAGES: "group_pages",
};

export default class RouteConditionEditor extends Component {
  @tracked advancedOpen = false;
  @tracked paramsJson = serialiseJson(this.args.leaf?.params);
  @tracked queryParamsJson = serialiseJson(this.args.leaf?.queryParams);
  @tracked paramsError = null;
  @tracked queryParamsError = null;
  isPageSelected = (id) => this.selectedPages.has(id);

  get pageTypes() {
    return VALID_PAGE_TYPES.map((id) => ({
      id,
      label: i18n(
        `wireframe.inspector.conditions.route_editor.pages.${PAGE_LABELS[id] ?? id.toLowerCase()}`
      ),
    }));
  }

  get selectedPages() {
    return new Set(
      Array.isArray(this.args.leaf?.pages) ? this.args.leaf.pages : []
    );
  }

  get urlsText() {
    const urls = this.args.leaf?.urls;
    if (!Array.isArray(urls)) {
      return "";
    }
    return urls.join("\n");
  }

  patch(patch) {
    const next = { ...this.args.leaf };
    for (const [k, v] of Object.entries(patch)) {
      if (v === undefined) {
        delete next[k];
      } else {
        next[k] = v;
      }
    }
    this.args.onChange(next);
  }

  @action
  togglePage(id) {
    const next = new Set(this.selectedPages);
    if (next.has(id)) {
      next.delete(id);
    } else {
      next.add(id);
    }
    const list = [...next];
    this.patch({ pages: list.length ? list : undefined });
  }

  @action
  setUrls(event) {
    const raw = event.target.value;
    const lines = raw
      .split("\n")
      .map((line) => line.trim())
      .filter(Boolean);
    this.patch({ urls: lines.length ? lines : undefined });
  }

  @action
  toggleAdvanced() {
    this.advancedOpen = !this.advancedOpen;
  }

  @action
  setParamsJson(event) {
    const raw = event.target.value;
    this.paramsJson = raw;
    if (raw.trim() === "") {
      this.paramsError = null;
      this.patch({ params: undefined });
      return;
    }
    try {
      const parsed = JSON.parse(raw);
      this.paramsError = null;
      this.patch({ params: parsed });
    } catch (err) {
      this.paramsError = err.message;
    }
  }

  @action
  setQueryParamsJson(event) {
    const raw = event.target.value;
    this.queryParamsJson = raw;
    if (raw.trim() === "") {
      this.queryParamsError = null;
      this.patch({ queryParams: undefined });
      return;
    }
    try {
      const parsed = JSON.parse(raw);
      this.queryParamsError = null;
      this.patch({ queryParams: parsed });
    } catch (err) {
      this.queryParamsError = err.message;
    }
  }

  <template>
    <div class="wireframe-condition-editor wireframe-condition-editor--route">
      <div class="wireframe-condition-editor__field">
        <span class="wireframe-condition-editor__legend">
          {{i18n "wireframe.inspector.conditions.route_editor.pages_legend"}}
        </span>
        <div class="wireframe-condition-editor__chip-grid" role="group">
          {{#each this.pageTypes as |page|}}
            <DButton
              class={{dConcatClass
                "wireframe-condition-editor__chip"
                (if (this.isPageSelected page.id) "--active")
              }}
              @ariaPressed={{this.isPageSelected page.id}}
              @translatedLabel={{page.label}}
              @action={{fn this.togglePage page.id}}
            />
          {{/each}}
        </div>
      </div>

      <div class="wireframe-condition-editor__field">
        <span class="wireframe-condition-editor__legend">
          {{i18n "wireframe.inspector.conditions.route_editor.urls_legend"}}
        </span>
        <textarea
          class="wireframe-condition-editor__textarea"
          rows="3"
          placeholder={{i18n
            "wireframe.inspector.conditions.route_editor.urls_placeholder"
          }}
          {{on "input" this.setUrls}}
        >{{this.urlsText}}</textarea>
        <span class="wireframe-condition-editor__help">
          {{i18n "wireframe.inspector.conditions.route_editor.urls_help"}}
        </span>
      </div>

      <DButton
        class="wireframe-condition-editor__advanced-toggle"
        @ariaExpanded={{this.advancedOpen}}
        @label={{if
          this.advancedOpen
          "wireframe.inspector.conditions.advanced_hide"
          "wireframe.inspector.conditions.advanced_show"
        }}
        @action={{this.toggleAdvanced}}
      />

      {{#if this.advancedOpen}}
        <div class="wireframe-condition-editor__field">
          <span class="wireframe-condition-editor__legend">
            {{i18n "wireframe.inspector.conditions.route_editor.params_legend"}}
          </span>
          <textarea
            class="wireframe-condition-editor__textarea --mono"
            rows="3"
            placeholder='{"categorySlug": "support"}'
            {{on "input" this.setParamsJson}}
          >{{this.paramsJson}}</textarea>
          {{#if this.paramsError}}
            <span class="wireframe-condition-editor__error">
              {{this.paramsError}}
            </span>
          {{/if}}
        </div>

        <div class="wireframe-condition-editor__field">
          <span class="wireframe-condition-editor__legend">
            {{i18n
              "wireframe.inspector.conditions.route_editor.query_params_legend"
            }}
          </span>
          <textarea
            class="wireframe-condition-editor__textarea --mono"
            rows="3"
            placeholder='{"filter": "solved"}'
            {{on "input" this.setQueryParamsJson}}
          >{{this.queryParamsJson}}</textarea>
          {{#if this.queryParamsError}}
            <span class="wireframe-condition-editor__error">
              {{this.queryParamsError}}
            </span>
          {{/if}}
        </div>
      {{/if}}
    </div>
  </template>
}

function serialiseJson(value) {
  if (value === undefined || value === null) {
    return "";
  }
  try {
    return JSON.stringify(value, null, 2);
  } catch {
    return "";
  }
}
