import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DiscourseURL from "discourse/lib/url";
import type Category from "discourse/models/category";
import TagSelectBase, {
  TagOption,
  TagSelection,
  type TagSelectSignature,
} from "discourse/ui-kit/select/recipes/tags/-internals/tag-select-base";
import type {
  HeldTag,
  TagObject,
} from "discourse/ui-kit/select/recipes/tags/-internals/tag-values";

/** Intersection filters retain tag objects and additional name-only tags. */
interface DTagsIntersectionChooserSignature extends Omit<
  TagSelectSignature,
  "Args"
> {
  Args: Omit<TagSelectSignature["Args"], "tags" | "kind" | "onChange"> & {
    /** Primary tag whose slug and id are retained for single-tag routes. */
    mainTag?: TagObject & { slug?: string };
    /** Additional tags in route order. */
    additionalTags?: readonly HeldTag[];
    /** Category limiting tag search. */
    currentCategory?: Category;
    /** Optional replacement for route navigation. */
    onChange?: (tags: TagObject[]) => void;
  };
}

/** Multi-tag filter navigating to the selected intersection. */
export default class DTagsIntersectionChooser extends Component<DTagsIntersectionChooserSignature> {
  get tags() {
    return [
      ...(this.args.mainTag ? [this.args.mainTag] : []),
      ...(this.args.additionalTags ?? []),
    ];
  }

  get categoryId(): number | undefined {
    return (
      this.args.categoryId ??
      (this.args.currentCategory as { id?: number } | undefined)?.id
    );
  }

  @action
  onChange(tags: TagObject[]) {
    if (this.args.onChange) {
      this.args.onChange(tags);
      return;
    }
    const main = this.args.mainTag;
    const names = tags.map((tag) => tag.name);
    if (main && names.includes(main.name)) {
      const remaining = names.filter((name) => name !== main.name);
      DiscourseURL.routeTo(
        remaining.length
          ? `/tags/intersection/${main.name}/${remaining.join("/")}`
          : main.id
            ? `/tag/${main.slug || `${main.id}-tag`}/${main.id}`
            : `/tag/${main.name}`
      );
    } else {
      DiscourseURL.routeTo(
        names.length >= 2
          ? `/tags/intersection/${names.join("/")}`
          : names.length
            ? `/tag/${names[0]}`
            : "/tags"
      );
    }
  }

  <template>
    <TagSelectBase
      ...attributes
      @categoryId={{this.categoryId}}
      @disabled={{@disabled}}
      @identifier={{@identifier}}
      @instanceContext={{@instanceContext}}
      @items={{@items}}
      @kind="tags-intersection-chooser"
      @kindContext={{hash
        mainTag=@mainTag
        additionalTags=@additionalTags
        currentCategory=@currentCategory
      }}
      @label={{@label}}
      @load={{@load}}
      @maximum={{@maximum}}
      @onChange={{this.onChange}}
      @placeholder={{@placeholder}}
      @tags={{this.tags}}
    >
      <:item as |item options|>{{#if (has-block "item")}}{{yield
            item
            options
            to="item"
          }}{{else}}<TagOption @item={{item}} />{{/if}}</:item>
      <:selection as |item options|>{{#if (has-block "selection")}}{{yield
            item
            options
            to="selection"
          }}{{else}}<TagSelection @item={{item}} />{{/if}}</:selection>
      <:footer as |state options|>{{yield state options to="footer"}}</:footer>
    </TagSelectBase>
  </template>
}
