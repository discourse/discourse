import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { hash } from "@ember/helper";
import SelectTagBase, {
  type SelectTagBaseSignature,
} from "discourse/ui-kit/select/recipes/tags/-internals/select-tag-base";
import {
  TagOption,
  TagSelection,
} from "discourse/ui-kit/select/recipes/tags/-internals/tag-renderers";

/** Arguments of `DSelectTag`, the shared tag base minus what only a recipe built on it sets. */
interface DSelectTagSignature extends Omit<SelectTagBaseSignature, "Args"> {
  Args: Omit<
    SelectTagBaseSignature["Args"],
    | "kind"
    | "kindContext"
    | "kindOptions"
    | "kindTexts"
    | "requirementPlaceholders"
    | "suppressFooter"
  >;
}

/** Picks tags to store, as tag objects or, with `@emit="names"`, stored names. */
const DSelectTag: TemplateOnlyComponent<DSelectTagSignature> = <template>
  <SelectTagBase
    ...attributes
    @allowCreate={{@allowCreate}}
    @ariaLabel={{@ariaLabel}}
    @categoryId={{@categoryId}}
    @describedBy={{@describedBy}}
    @disabled={{@disabled}}
    @emit={{@emit}}
    @exclude={{@exclude}}
    @excludeSynonyms={{@excludeSynonyms}}
    @excludeTagsWithSynonyms={{@excludeTagsWithSynonyms}}
    @icon={{@icon}}
    @id={{@id}}
    @identifier={{@identifier}}
    @ignoreRestrictions={{@ignoreRestrictions}}
    @instanceContext={{@instanceContext}}
    @invalid={{@invalid}}
    @items={{@items}}
    @kind="select-tag"
    @kindContext={{hash value=@value categoryId=@categoryId exclude=@exclude}}
    @legacyKind={{if @legacyKind @legacyKind "tag-chooser"}}
    @load={{@load}}
    @maximum={{@maximum}}
    @maxVisibleChips={{@maxVisibleChips}}
    @minimum={{@minimum}}
    @multiple={{@multiple}}
    @onChange={{@onChange}}
    @placeholder={{@placeholder}}
    @suggestRecent={{@suggestRecent}}
    @suppressFooter={{not (has-block "footer")}}
    @texts={{@texts}}
    @value={{@value}}
    @variant={{@variant}}
  >
    <:item as |item options|>
      {{#if (has-block "item")}}
        {{yield item options to="item"}}
      {{else}}
        <TagOption @item={{item}} @options={{options}} />
      {{/if}}
    </:item>
    <:selection as |item options|>
      {{#if (has-block "selection")}}
        {{yield item options to="selection"}}
      {{else}}
        <TagSelection @item={{item}} />
      {{/if}}
    </:selection>
    <:footer as |state options|>
      {{yield state options to="footer"}}
    </:footer>
  </SelectTagBase>
</template>;

export default DSelectTag;
