import type { TemplateOnlyComponent } from "@ember/component/template-only";
import dDiscourseTag from "discourse/ui-kit/helpers/d-discourse-tag";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import {
  renderSelectText,
  type SelectItem,
  type SelectItemRow,
  type SelectResolvedOptions,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

/** The translations a row's texts default to when it's drawn without the select's options. */
const ROW_TEXT_KEYS: Readonly<Record<string, string>> = {
  createItem: "d_select.create_item",
  tagCountBadge: "tagging.tag_count_badge",
  tagCount: "tagging.tag_count_hidden",
};

/** A row text, from the select's options when the row has them. */
function rowText(
  options: SelectResolvedOptions | undefined,
  key: string,
  values: object
): string {
  return options
    ? renderSelectText(options, key, values)
    : i18n(ROW_TEXT_KEYS[key]!, values);
}

/** The values of a row's count texts. */
function countValues(item: SelectItem) {
  return { count: tagCount(item) };
}

/** The values of the create row's text. */
function createValues(item: SelectItem) {
  return { label: tagItemName(item) };
}

/** Narrows optional source counts at the rendering boundary. */
function tagCount(item: SelectItem): number {
  return typeof item.count === "number" ? item.count : 0;
}

/** Narrows the optional synonym target supplied by tag search. */
function synonymName(item: SelectItem): string | undefined {
  const target = item.target_tag;
  return typeof target === "object" &&
    target !== null &&
    "name" in target &&
    typeof target.name === "string"
    ? target.name
    : undefined;
}

/** An item's display name, narrowed for templates. */
export function tagItemName(item: SelectItem): string {
  return typeof item.name === "string" ? item.name : String(item.name ?? "");
}

/** Narrows optional action icons at the rendering boundary. */
function actionIcon(item: SelectItem): string | undefined {
  return typeof item.icon === "string" ? item.icon : undefined;
}

/** Default option content shared with forwarding recipes. */
export const TagOption: TemplateOnlyComponent<{
  Args: {
    /** The tag row, including its optional count and synonym target. */
    item: SelectItem;
    /** The select's resolved options, which carry its texts. */
    options?: SelectResolvedOptions;
    /** The row's state, which says whether it's the create row. */
    row: SelectItemRow;
  };
}> = <template>
  {{#if @item.onSelect}}
    {{#if (actionIcon @item)}}{{dIcon (actionIcon @item)}}{{/if}}
    {{tagItemName @item}}
  {{else if @row.create}}
    {{rowText @options "createItem" (createValues @item)}}
  {{else}}
    <span class="d-tag-option">
      {{dDiscourseTag @item.name noHref=true tagName="span"}}
      {{#if @item.count}}
        {{#let
          (rowText @options "tagCountBadge" (countValues @item))
          (rowText @options "tagCount" (countValues @item))
          as |badge spoken|
        }}
          {{#if badge}}
            <span aria-hidden="true" class="discourse-tag-count">
              {{~badge~}}
            </span>
          {{/if}}
          {{#if spoken}}
            <span class="sr-only">
              {{~spoken~}}
            </span>
          {{/if}}
        {{/let}}
      {{/if}}
      {{#if @item.target_tag}}
        <span class="synonym-hint"><span aria-hidden="true">→</span>
          {{synonymName @item~}}
        </span>
      {{/if}}
    </span>
  {{/if}}
</template>;

/** Default held-tag content shared with forwarding recipes. */
export const TagSelection: TemplateOnlyComponent<{
  Args: {
    /** The held tag supplied by the engine. */
    item: SelectItem;
  };
}> = <template>
  {{dDiscourseTag @item.name noHref=true tagName="span"}}
</template>;
