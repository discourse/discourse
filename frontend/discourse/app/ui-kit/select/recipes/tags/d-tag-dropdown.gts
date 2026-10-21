import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DiscourseURL from "discourse/lib/url";
import DSelect from "discourse/ui-kit/select/d-select";
import { tagItemName } from "discourse/ui-kit/select/recipes/tags/tag-select-base";
import type {
  SelectItem,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";

/** Engine arguments reused by the tag settings selector. */
type SelectSignature =
  DSelect extends Component<infer Signature> ? Signature : never;

/** Selects a tag by name while preserving its numeric id for navigation. */
interface DTagDropdownSignature {
  Args: {
    /** Available tags in display order. */
    tags: Array<{ id: number | string; name: string }>;
    /** Currently displayed tag name. */
    value?: string;
    /** Call-site customization identity. */
    identifier?: string;
    /** Call-site customization data. */
    instanceContext?: object;
    /** Optional replacement for the local tag source. */
    items?: SelectSignature["Args"]["items"];
    /** Optional asynchronous source. */
    load?: SelectSignature["Args"]["load"];
    /** Optional replacement for navigation. */
    onChange?: SelectSignature["Args"]["onChange"];
    /** Accessible label. */
    label?: string;
    /** Prevent opening or selecting. */
    disabled?: boolean;
  };
  Element: HTMLElement;
  Blocks: Pick<SelectSignature["Blocks"], "item" | "selection" | "footer">;
}

/** Tag settings navigation with name-valued selection. */
export default class DTagDropdown extends Component<DTagDropdownSignature> {
  @action
  onChange(
    value: SelectValue,
    item: SelectItem | SelectItem[] | null,
    meta: Parameters<NonNullable<SelectSignature["Args"]["onChange"]>>[2]
  ) {
    if (this.args.onChange) {
      this.args.onChange(value, item, meta);
      return;
    }
    const tag = this.args.tags.find((candidate) => candidate.name === value);
    if (tag) {
      DiscourseURL.routeToUrl(`/tag/${tag.name}/${tag.id}/edit/general`);
    }
  }

  <template>
    {{! TODO (select-kit-replacement-cleanup): Retain the legacy family class during rollout. }}
    <DSelect
      class="tag-dropdown"
      ...attributes
      @caretIcon={{hash open="caret-up" closed="caret-down"}}
      @disabled={{@disabled}}
      @identifier={{@identifier}}
      @instanceContext={{@instanceContext}}
      @items={{if @items @items @tags}}
      @kind="tag-dropdown"
      @kindContext={{hash tags=@tags}}
      @label={{@label}}
      @labelField="name"
      @load={{@load}}
      @onChange={{this.onChange}}
      @value={{@value}}
      @valueField="name"
      @valueItems={{@tags}}
      @variant="button"
    >
      <:item as |item options|>{{#if (has-block "item")}}{{yield
            item
            options
            to="item"
          }}{{else}}{{tagItemName item}}{{/if}}</:item>
      <:selection as |item options|>{{#if (has-block "selection")}}{{yield
            item
            options
            to="selection"
          }}{{else}}{{tagItemName item}}{{/if}}</:selection>
      <:footer as |state options|>{{yield state options to="footer"}}</:footer>
    </DSelect>
  </template>
}
