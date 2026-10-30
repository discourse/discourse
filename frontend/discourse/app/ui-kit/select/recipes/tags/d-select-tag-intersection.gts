import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import { assertNoRemovedTextArgs } from "discourse/ui-kit/select/-internals/engine/select-texts";
import type DSelect from "discourse/ui-kit/select/d-select";
import SelectTagBase, {
  type SelectTagTextKey,
} from "discourse/ui-kit/select/recipes/tags/-internals/select-tag-base";
import {
  TagOption,
  TagSelection,
} from "discourse/ui-kit/select/recipes/tags/-internals/tag-renderers";
import type { TagObject } from "discourse/ui-kit/select/recipes/tags/-internals/tag-values";
import type {
  SelectItem,
  SelectTexts,
} from "discourse/ui-kit/select/select-engine";

/** The intersection's name and empty text, above the tag field's. */
const INTERSECTION_TEXTS: SelectTexts = Object.freeze({
  ariaLabel: { key: "tagging.filter_by_tags_label" },
  placeholder: { key: "tagging.selector_tags" },
});

/** Engine blocks and source overrides shared with callers. */
type SelectSignature =
  DSelect extends Component<infer Signature> ? Signature : never;

/** A topic-list filter holding several tags, leaving navigation to its caller. */
interface DSelectTagIntersectionSignature {
  Args: {
    /** The held tags, in order. */
    value?: readonly TagObject[];
    /** Category limiting the available tags. */
    categoryId?: number;
    /** Temporary compatibility aliases for legacy customizations and CSS. */
    legacyKind?: SelectSignature["Args"]["legacyKind"];
    /** Local tags replacing the server search. */
    items?: readonly SelectItem[];
    /** Optional asynchronous source override. */
    load?: SelectSignature["Args"]["load"];
    /** Receives the held tags in order. */
    onChange?: (tags: TagObject[]) => void;
    /** Call-site customization identity. */
    identifier?: string;
    /** Call-site state exposed to customizations. */
    instanceContext?: object;
    /** The intersection's texts, over its defaults. */
    texts?: SelectTexts<SelectTagTextKey>;
    /** Prevent opening or selecting. */
    disabled?: boolean;
    /** Ids of visible captions that name the control, replacing "Filter by: tags". */
    ariaLabelledBy?: string;
  };
  Element: HTMLElement;
  Blocks: Pick<SelectSignature["Blocks"], "item" | "selection" | "footer">;
}

/** Selects several tags for a topic-list intersection without navigating. */
export default class DSelectTagIntersection extends Component<DSelectTagIntersectionSignature> {
  kindTexts = INTERSECTION_TEXTS;

  constructor(owner: Owner, args: DSelectTagIntersectionSignature["Args"]) {
    super(owner, args);
    assertNoRemovedTextArgs("DSelectTagIntersection", args);
  }

  get legacyKind() {
    return (
      this.args.legacyKind ?? ["tags-intersection-chooser", "mini-tag-chooser"]
    );
  }

  get localItems() {
    return this.args.items ? [...this.args.items] : undefined;
  }

  @action
  onChange(tags: TagObject[] | TagObject | string[] | string | null) {
    if (Array.isArray(tags)) {
      this.args.onChange?.(tags as TagObject[]);
    }
  }

  <template>
    <SelectTagBase
      ...attributes
      @ariaLabelledBy={{@ariaLabelledBy}}
      @categoryId={{@categoryId}}
      @disabled={{@disabled}}
      @identifier={{@identifier}}
      @instanceContext={{@instanceContext}}
      @items={{this.localItems}}
      @kind="select-tag-intersection"
      @kindContext={{hash value=@value categoryId=@categoryId}}
      @kindTexts={{this.kindTexts}}
      @legacyKind={{this.legacyKind}}
      @load={{@load}}
      @multiple={{true}}
      @onChange={{this.onChange}}
      @requirementPlaceholders={{false}}
      @suppressFooter={{not (has-block "footer")}}
      @texts={{@texts}}
      @value={{@value}}
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
  </template>
}
