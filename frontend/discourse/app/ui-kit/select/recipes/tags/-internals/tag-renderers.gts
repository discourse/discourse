import type { TemplateOnlyComponent } from "@ember/component/template-only";
import dDiscourseTag from "discourse/ui-kit/helpers/d-discourse-tag";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import {
  renderSelectText,
  type SelectConfig,
  type SelectOption,
  type SelectRecord,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

/** The translations a row's texts default to when it's drawn without the select's options. */
const ROW_TEXT_KEYS: Readonly<Record<string, string>> = {
  createOption: "d_select.create_item",
  tagCountBadge: "tagging.tag_count_badge",
  tagCount: "tagging.tag_count_hidden",
};

/** A row text, from the select's options when the row has them. */
function rowText(
  config: SelectConfig | undefined,
  key: string,
  values: object
): string {
  return config
    ? renderSelectText(config, key, values)
    : i18n(ROW_TEXT_KEYS[key]!, values);
}

/** The values of a row's count texts. */
function countValues(record: SelectRecord) {
  return { count: tagCount(record) };
}

/** The values of the create row's text. */
function createValues(record: SelectRecord) {
  return { label: tagRecordName(record) };
}

/** Narrows optional source counts at the rendering boundary. */
function tagCount(record: SelectRecord): number {
  return typeof record.count === "number" ? record.count : 0;
}

/** Narrows the optional synonym target supplied by tag search. */
function synonymName(record: SelectRecord): string | undefined {
  const target = record.target_tag;
  return typeof target === "object" &&
    target !== null &&
    "name" in target &&
    typeof target.name === "string"
    ? target.name
    : undefined;
}

/** A record's display name, narrowed for templates. */
export function tagRecordName(record: SelectRecord): string {
  return typeof record.name === "string"
    ? record.name
    : String(record.name ?? "");
}

/** Narrows optional action icons at the rendering boundary. */
function actionIcon(record: SelectRecord): string | undefined {
  return typeof record.icon === "string" ? record.icon : undefined;
}

/** Default option content shared with forwarding recipes. */
export const TagOption: TemplateOnlyComponent<{
  Args: {
    /** The tag row, including its optional count and synonym target. */
    record: SelectRecord;
    /** The select's resolved config, which carries its texts. */
    config?: SelectConfig;
    /** The option drawn, which says whether it's an action or the create option; absent in the selection. */
    option?: SelectOption;
  };
}> = <template>
  {{#if @option.action}}
    {{#if (actionIcon @record)}}{{dIcon (actionIcon @record)}}{{/if}}
    {{tagRecordName @record}}
  {{else if @option.create}}
    {{rowText @config "createOption" (createValues @record)}}
  {{else}}
    <span class="d-tag-option">
      {{dDiscourseTag @record.name noHref=true tagName="span"}}
      {{#if @record.count}}
        {{#let
          (rowText @config "tagCountBadge" (countValues @record))
          (rowText @config "tagCount" (countValues @record))
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
      {{#if @record.target_tag}}
        <span class="synonym-hint"><span aria-hidden="true">→</span>
          {{synonymName @record~}}
        </span>
      {{/if}}
    </span>
  {{/if}}
</template>;

/** Default held-tag content shared with forwarding recipes. */
export const TagSelection: TemplateOnlyComponent<{
  Args: {
    /** The held tag supplied by the engine. */
    record: SelectRecord;
  };
}> = <template>
  {{dDiscourseTag @record.name noHref=true tagName="span"}}
</template>;
