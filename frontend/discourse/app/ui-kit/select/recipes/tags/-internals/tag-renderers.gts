import type { TemplateOnlyComponent } from "@ember/component/template-only";
import dDiscourseTag from "discourse/ui-kit/helpers/d-discourse-tag";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import type { SelectItem } from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

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
  };
}> = <template>
  {{#if @item.onSelect}}
    {{#if (actionIcon @item)}}{{dIcon (actionIcon @item)}}{{/if}}
    {{tagItemName @item}}
  {{else if @item.isNew}}
    {{i18n "d_select.create_item" label=@item.name}}
  {{else}}
    <span class="d-tag-option">
      {{dDiscourseTag @item.name noHref=true tagName="span"}}
      {{#if @item.count}}
        <span aria-hidden="true" class="discourse-tag-count">
          {{~i18n "tagging.tag_count_badge" count=(tagCount @item)~}}
        </span>
        <span class="sr-only">
          {{~i18n "tagging.tag_count_hidden" count=(tagCount @item)~}}
        </span>
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
