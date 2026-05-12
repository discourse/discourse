// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { VALID_PAGE_TYPES } from "discourse/lib/blocks/-internals/matching/page-definitions";
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
 *     disclosure as raw JSON for now (a structured editor would need
 *     the page-type's params schema, deferred to a later phase).
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
  isPageSelected = (id) => this.selectedPages.has(id);
  @tracked _advancedOpen = false;
  @tracked _paramsJson = serialiseJson(this.args.leaf?.params);
  @tracked _queryParamsJson = serialiseJson(this.args.leaf?.queryParams);
  @tracked _paramsError = null;
  @tracked _queryParamsError = null;

  get pageTypes() {
    return VALID_PAGE_TYPES.map((id) => ({
      id,
      label: i18n(
        `visual_editor.inspector.conditions.route_editor.pages.${PAGE_LABELS[id] ?? id.toLowerCase()}`
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
  toggleAdvanced(event) {
    event.preventDefault();
    this._advancedOpen = !this._advancedOpen;
  }

  @action
  setParamsJson(event) {
    const raw = event.target.value;
    this._paramsJson = raw;
    if (raw.trim() === "") {
      this._paramsError = null;
      this.patch({ params: undefined });
      return;
    }
    try {
      const parsed = JSON.parse(raw);
      this._paramsError = null;
      this.patch({ params: parsed });
    } catch (err) {
      this._paramsError = err.message;
    }
  }

  @action
  setQueryParamsJson(event) {
    const raw = event.target.value;
    this._queryParamsJson = raw;
    if (raw.trim() === "") {
      this._queryParamsError = null;
      this.patch({ queryParams: undefined });
      return;
    }
    try {
      const parsed = JSON.parse(raw);
      this._queryParamsError = null;
      this.patch({ queryParams: parsed });
    } catch (err) {
      this._queryParamsError = err.message;
    }
  }

  <template>
    <div
      class="visual-editor-condition-editor visual-editor-condition-editor--route"
    >
      <div class="visual-editor-condition-editor__field">
        <span class="visual-editor-condition-editor__legend">
          {{i18n
            "visual_editor.inspector.conditions.route_editor.pages_legend"
          }}
        </span>
        <div class="visual-editor-condition-editor__chip-grid" role="group">
          {{#each this.pageTypes as |page|}}
            <button
              type="button"
              class={{dConcatClass
                "visual-editor-condition-editor__chip"
                (if (this.isPageSelected page.id) "--active")
              }}
              aria-pressed={{this.isPageSelected page.id}}
              {{on "click" (fn this.togglePage page.id)}}
            >
              <span>{{page.label}}</span>
            </button>
          {{/each}}
        </div>
      </div>

      <div class="visual-editor-condition-editor__field">
        <span class="visual-editor-condition-editor__legend">
          {{i18n "visual_editor.inspector.conditions.route_editor.urls_legend"}}
        </span>
        <textarea
          class="visual-editor-condition-editor__textarea"
          rows="3"
          placeholder={{i18n
            "visual_editor.inspector.conditions.route_editor.urls_placeholder"
          }}
          {{on "input" this.setUrls}}
        >{{this.urlsText}}</textarea>
        <span class="visual-editor-condition-editor__help">
          {{i18n "visual_editor.inspector.conditions.route_editor.urls_help"}}
        </span>
      </div>

      <button
        type="button"
        class="visual-editor-condition-editor__advanced-toggle"
        aria-expanded={{this._advancedOpen}}
        {{on "click" this.toggleAdvanced}}
      >
        {{if
          this._advancedOpen
          (i18n "visual_editor.inspector.conditions.advanced_hide")
          (i18n "visual_editor.inspector.conditions.advanced_show")
        }}
      </button>

      {{#if this._advancedOpen}}
        <div class="visual-editor-condition-editor__field">
          <span class="visual-editor-condition-editor__legend">
            {{i18n
              "visual_editor.inspector.conditions.route_editor.params_legend"
            }}
          </span>
          <textarea
            class="visual-editor-condition-editor__textarea --mono"
            rows="3"
            placeholder='{"categorySlug": "support"}'
            {{on "input" this.setParamsJson}}
          >{{this._paramsJson}}</textarea>
          {{#if this._paramsError}}
            <span class="visual-editor-condition-editor__error">
              {{this._paramsError}}
            </span>
          {{/if}}
        </div>

        <div class="visual-editor-condition-editor__field">
          <span class="visual-editor-condition-editor__legend">
            {{i18n
              "visual_editor.inspector.conditions.route_editor.query_params_legend"
            }}
          </span>
          <textarea
            class="visual-editor-condition-editor__textarea --mono"
            rows="3"
            placeholder='{"filter": "solved"}'
            {{on "input" this.setQueryParamsJson}}
          >{{this._queryParamsJson}}</textarea>
          {{#if this._queryParamsError}}
            <span class="visual-editor-condition-editor__error">
              {{this._queryParamsError}}
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
