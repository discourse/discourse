import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { hash } from "@ember/helper";
import TagSelectBase, {
  TagOption,
  TagSelection,
  type TagSelectSignature,
} from "discourse/ui-kit/select/recipes/tags/-internals/tag-select-base";

/** A controlled tag chooser with creation disabled unless explicitly allowed. */
interface DTagChooserSignature extends Omit<TagSelectSignature, "Args"> {
  Args: Omit<
    TagSelectSignature["Args"],
    "kind" | "kindContext" | "kindOptions"
  >;
}

/** Multi-tag chooser for preferences and other tag fields. */
const DTagChooser: TemplateOnlyComponent<DTagChooserSignature> = <template>
  <TagSelectBase
    ...attributes
    @allowCreate={{@allowCreate}}
    @blockedTags={{@blockedTags}}
    @categoryId={{@categoryId}}
    @describedBy={{@describedBy}}
    @disabled={{@disabled}}
    @everyTag={{@everyTag}}
    @excludeHasSynonyms={{@excludeHasSynonyms}}
    @excludeSynonyms={{@excludeSynonyms}}
    @id={{@id}}
    @identifier={{@identifier}}
    @instanceContext={{@instanceContext}}
    @invalid={{@invalid}}
    @items={{@items}}
    @kind="tag-chooser"
    @kindContext={{hash
      tags=@tags
      blockedTags=@blockedTags
      categoryId=@categoryId
    }}
    @label={{@label}}
    @load={{@load}}
    @maximum={{@maximum}}
    @minimum={{@minimum}}
    @onChange={{@onChange}}
    @placeholder={{@placeholder}}
    @tags={{@tags}}
    @unlimitedTagCount={{@unlimitedTagCount}}
  >
    <:item as |item options|>
      {{#if (has-block "item")}}{{yield
          item
          options
          to="item"
        }}{{else}}<TagOption @item={{item}} />{{/if}}
    </:item>
    <:selection as |item options|>
      {{#if (has-block "selection")}}{{yield
          item
          options
          to="selection"
        }}{{else}}<TagSelection @item={{item}} />{{/if}}
    </:selection>
    <:footer as |state options|>{{yield state options to="footer"}}</:footer>
  </TagSelectBase>
</template>;

export default DTagChooser;
