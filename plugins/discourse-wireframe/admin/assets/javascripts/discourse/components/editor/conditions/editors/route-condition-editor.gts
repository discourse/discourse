import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { VALID_PAGE_TYPES } from "discourse/lib/blocks/-internals/matching/page-definitions";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import type { ConditionLeaf } from "discourse/plugins/discourse-wireframe/discourse/lib/conditions/condition-tree";

type RouteConditionLeaf = ConditionLeaf & {
  /** Semantic page types matched by the route. */
  pages?: string[];
  /** URL glob patterns matched by the route. */
  urls?: string[];
  /** Route parameter constraints. */
  params?: unknown;
  /** Query-parameter constraints. */
  queryParams?: unknown;
};

type PageTypeOption = {
  /** Core page-type identifier. */
  id: string;
  /** Translated page-type label. */
  label: string;
};

interface RouteConditionEditorSignature {
  /** Route condition and update callback. */
  Args: {
    /** Route condition leaf being edited. */
    leaf: RouteConditionLeaf;
    /** Replaces the edited condition leaf. */
    onChange: (
      /** Updated route condition leaf. */
      leaf: RouteConditionLeaf
    ) => void;
  };
}

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
const PAGE_LABELS: Readonly<Record<string, string>> = {
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

export default class RouteConditionEditor extends Component<RouteConditionEditorSignature> {
  /** Whether the advanced JSON editors are expanded. */
  @tracked advancedOpen = false;
  /** Editable JSON representation of route parameters. */
  @tracked
  paramsJson: string | undefined = serialiseJson(this.args.leaf?.params);
  /** Editable JSON representation of query parameters. */
  @tracked queryParamsJson: string | undefined = serialiseJson(
    this.args.leaf?.queryParams
  );
  /** Current route-parameter parse error. */
  @tracked paramsError: string | null = null;
  /** Current query-parameter parse error. */
  @tracked queryParamsError: string | null = null;
  /**
   * Checks whether a page type is selected.
   *
   * @param id - Core page-type identifier.
   * @returns Whether the page type is selected.
   */
  isPageSelected: (id: string) => boolean = (id) => this.selectedPages.has(id);

  /** Core page types paired with translated labels. */
  get pageTypes(): PageTypeOption[] {
    return VALID_PAGE_TYPES.map((id) => ({
      id,
      label: i18n(
        `wireframe.inspector.conditions.route_editor.pages.${PAGE_LABELS[id] ?? id.toLowerCase()}`
      ),
    }));
  }

  /** Selected semantic page types. */
  get selectedPages(): Set<string> {
    return new Set(
      Array.isArray(this.args.leaf?.pages) ? this.args.leaf.pages : []
    );
  }

  /** URL patterns rendered one per line. */
  get urlsText(): string {
    const urls = this.args.leaf?.urls;
    if (!Array.isArray(urls)) {
      return "";
    }
    return urls.join("\n");
  }

  /**
   * Applies a partial route-condition update, deleting undefined fields.
   *
   * @param patch - Condition fields to replace or remove.
   */
  patch(patch: Partial<RouteConditionLeaf>): void {
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

  /**
   * Toggles one semantic page type.
   *
   * @param id - Core page-type identifier.
   */
  @action
  togglePage(id: string): void {
    const next = new Set(this.selectedPages);
    if (next.has(id)) {
      next.delete(id);
    } else {
      next.add(id);
    }
    const list = [...next];
    this.patch({ pages: list.length ? list : undefined });
  }

  /**
   * Parses newline-delimited URL patterns.
   *
   * @param event - URL-pattern textarea event.
   */
  @action
  setUrls(event: Event): void {
    if (!(event.currentTarget instanceof HTMLTextAreaElement)) {
      return;
    }
    const raw = event.currentTarget.value;
    const lines = raw
      .split("\n")
      .map((line) => line.trim())
      .filter(Boolean);
    this.patch({ urls: lines.length ? lines : undefined });
  }

  /** Toggles the advanced parameter editors. */
  @action
  toggleAdvanced(): void {
    this.advancedOpen = !this.advancedOpen;
  }

  /**
   * Parses and applies route-parameter JSON.
   *
   * @param event - Route-parameter textarea event.
   */
  @action
  setParamsJson(event: Event): void {
    if (!(event.currentTarget instanceof HTMLTextAreaElement)) {
      return;
    }
    const raw = event.currentTarget.value;
    this.paramsJson = raw;
    if (raw.trim() === "") {
      this.paramsError = null;
      this.patch({ params: undefined });
      return;
    }
    try {
      const parsed: unknown = JSON.parse(raw);
      this.paramsError = null;
      this.patch({ params: parsed });
    } catch (error) {
      this.paramsError = error instanceof Error ? error.message : String(error);
    }
  }

  /**
   * Parses and applies query-parameter JSON.
   *
   * @param event - Query-parameter textarea event.
   */
  @action
  setQueryParamsJson(event: Event): void {
    if (!(event.currentTarget instanceof HTMLTextAreaElement)) {
      return;
    }
    const raw = event.currentTarget.value;
    this.queryParamsJson = raw;
    if (raw.trim() === "") {
      this.queryParamsError = null;
      this.patch({ queryParams: undefined });
      return;
    }
    try {
      const parsed: unknown = JSON.parse(raw);
      this.queryParamsError = null;
      this.patch({ queryParams: parsed });
    } catch (error) {
      this.queryParamsError =
        error instanceof Error ? error.message : String(error);
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

/**
 * Serializes a route constraint for a JSON textarea.
 *
 * @param value - Constraint value to serialize.
 * @returns Pretty JSON, or an empty string when absent or unserializable.
 */
function serialiseJson(value: unknown): string | undefined {
  if (value === undefined || value === null) {
    return "";
  }
  try {
    return JSON.stringify(value, null, 2);
  } catch {
    return "";
  }
}
