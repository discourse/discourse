import type { TOC } from "@ember/component/template-only";
import TopicStatus from "discourse/components/topic-status";
import type Category from "discourse/models/category";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import type { SelectItem } from "discourse/ui-kit/select/select-engine";

/** A topic's title, or the name an unresolved held topic was given. */
function topicTitle(item: SelectItem): string {
  return typeof item.title === "string" ? item.title : "";
}

/** The topic's category badge with its parents, when the site knows the category. */
function categoryBadge(item: SelectItem) {
  const category = item.category as Category | undefined;
  return category
    ? dCategoryBadge(category, {
        ancestors: category.predecessors,
        decorativeEmoji: true,
        hideParent: true,
      })
    : undefined;
}

/** The badge of the topic's own category alone, for a one-line field. */
function ownCategoryBadge(item: SelectItem) {
  const category = item.category as Category | undefined;
  return category
    ? dCategoryBadge(category, { decorativeEmoji: true, hideParent: true })
    : undefined;
}

/** A topic row: its status icons, its title and its category. */
export const TopicOption: TOC<{
  Args: {
    /** The topic. */
    item: SelectItem;
  };
}> = <template>
  <span class="d-topic-option">
    <TopicStatus @disableActions={{true}} @topic={{@item}} />
    <span class="d-topic-option__title">
      {{~dReplaceEmoji (topicTitle @item)~}}
    </span>
    {{#let (categoryBadge @item) as |badge|}}
      {{#if badge}}
        <span class="d-topic-option__category">
          {{~badge~}}
        </span>
      {{/if}}
    {{/let}}
  </span>
</template>;

/** A held topic: its title, and optionally its category. */
export const TopicSelection: TOC<{
  Args: {
    /** The held topic. */
    item: SelectItem;
    /** Draws the category badge beside the title, which tells similar titles apart. */
    withCategory?: boolean;
  };
}> = <template>
  {{#if @withCategory}}
    <span class="d-topic-selection">
      <span class="d-topic-selection__title">
        {{~dReplaceEmoji (topicTitle @item)~}}
      </span>
      {{#let (ownCategoryBadge @item) as |badge|}}
        {{#if badge}}
          <span class="d-topic-selection__category">
            {{~badge~}}
          </span>
        {{/if}}
      {{/let}}
    </span>
  {{else}}
    {{~dReplaceEmoji (topicTitle @item)~}}
  {{/if}}
</template>;
