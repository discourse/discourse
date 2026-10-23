import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { hash } from "@ember/helper";
import TagSelectBase, {
  TagOption,
  TagSelection,
  type TagSelectSignature,
} from "discourse/ui-kit/select/recipes/tags/-internals/tag-select-base";

/** Topic tag field accepting server tags, draft objects and plain names. */
interface DMiniTagChooserSignature extends Omit<TagSelectSignature, "Args"> {
  Args: Omit<
    TagSelectSignature["Args"],
    | "kind"
    | "kindContext"
    | "kindOptions"
    | "creationPolicy"
    | "allowCreate"
    | "tags"
  > & {
    /** Allow creation without site permission; site permission also enables creation. */
    allowCreate?: boolean;
    /** Controlled held tags in the surrounding model's original shape. */
    value?: TagSelectSignature["Args"]["tags"];
  };
}

/** Compact topic tag chooser; creation follows site permission or an explicit opt-in. */
const DMiniTagChooser: TemplateOnlyComponent<DMiniTagChooserSignature> =
  <template>
    <TagSelectBase
      ...attributes
      @allowCreate={{@allowCreate}}
      @blockedTags={{@blockedTags}}
      @categoryId={{@categoryId}}
      @creationPolicy="permitted"
      @describedBy={{@describedBy}}
      @disabled={{@disabled}}
      @everyTag={{@everyTag}}
      @excludeHasSynonyms={{@excludeHasSynonyms}}
      @excludeSynonyms={{@excludeSynonyms}}
      @hiddenValues={{@hiddenValues}}
      @icon={{@icon}}
      @id={{@id}}
      @identifier={{@identifier}}
      @instanceContext={{@instanceContext}}
      @invalid={{@invalid}}
      @items={{@items}}
      @kind="mini-tag-chooser"
      @kindContext={{hash
        value=@value
        blockedTags=@blockedTags
        categoryId=@categoryId
      }}
      @label={{@label}}
      @load={{@load}}
      @maximum={{@maximum}}
      @maxVisibleChips={{@maxVisibleChips}}
      @minimum={{@minimum}}
      @onChange={{@onChange}}
      @placeholder={{@placeholder}}
      @preventCreate={{@preventCreate}}
      @prioritizeRecentTags={{@prioritizeRecentTags}}
      @tags={{@value}}
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

export default DMiniTagChooser;
