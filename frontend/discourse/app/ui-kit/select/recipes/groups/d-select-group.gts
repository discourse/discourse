import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { assert } from "@ember/debug";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import { service } from "@ember/service";
import { makeArray } from "discourse/lib/helpers";
import type Site from "discourse/models/site";
import { assertNoRemovedTextArgs } from "discourse/ui-kit/select/-internals/engine/select-texts";
import DSelect, {
  type DSelectSignature,
} from "discourse/ui-kit/select/d-select";
import {
  groupFields,
  GroupOption,
  type GroupRecord,
  itemName,
} from "discourse/ui-kit/select/recipes/groups/-internals/group-renderers";
import type {
  SelectCoreTexts,
  SelectItem,
  SelectTexts,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

/** A group the picker offers; `automatic` decides whether `@automatic={{false}}` drops it. */
type GroupSource = GroupRecord & { automatic?: boolean };

/** The group picker's arguments and the engine's forwarded presentation contract. */
interface DSelectGroupSignature {
  Args: Pick<
    DSelectSignature["Args"],
    | "ariaLabelledBy"
    | "clearable"
    | "describedBy"
    | "disabled"
    | "icon"
    | "id"
    | "identifier"
    | "instanceContext"
    | "invalid"
    | "legacyKind"
    | "maximum"
    | "maxVisibleChips"
    | "onClose"
    | "variant"
  > & {
    /** Held group ids, or names with `@emit="names"`. */
    value?: number | string | readonly (number | string)[] | null;
    /** Holds several groups; defaults to one, as DSelect does. */
    multiple?: boolean;
    /** Holds and emits group names instead of ids. Names and string ids can't be told apart, so both follow it. */
    emit?: "names";
    /** Offers automatic groups; defaults to true. */
    automatic?: boolean;
    /** Offers the everyone group; defaults to true. */
    everyone?: boolean;
    /** Ids of groups never offered; a held one stays selected. */
    exclude?: readonly number[];
    /** Ids of the only groups offered. */
    only?: readonly number[];
    /**
     * Groups to offer instead of the site's, for a call site that loads its own list. The
     * other filters still apply.
     */
    items?: readonly GroupSource[];
    /** The picker's texts, over its defaults. */
    texts?: SelectCoreTexts;
    /** Receives the held ids or names: an array when multiple, otherwise one or `null`. */
    onChange?: (value: (number | string)[] | number | string | null) => void;
  };
  Element: HTMLElement;
  Blocks: Pick<DSelectSignature["Blocks"], "item" | "selection" | "footer">;
}

/** Picks from the site's groups, filtered locally. */
export default class DSelectGroup extends Component<DSelectGroupSignature> {
  @service declare site: Site;

  /** The picker's texts: "Group" while it holds at most one, otherwise "Groups". */
  kindTexts: SelectTexts = {
    ariaLabel: (_values, context) =>
      context.multiple && this.args.maximum !== 1
        ? i18n("select_group.groups")
        : i18n("select_group.group"),
  };

  constructor(owner: Owner, args: DSelectGroupSignature["Args"]) {
    super(owner, args);
    assertNoRemovedTextArgs("DSelectGroup", args);
  }

  @cached
  get items(): SelectItem[] {
    const exclude = new Set(this.args.exclude ?? []);
    const only = this.args.only ? new Set(this.args.only) : undefined;
    const byName = this.args.emit === "names";
    return (this.args.items ?? (this.site.groups as GroupSource[]))
      .filter(
        (group) =>
          (this.args.automatic !== false || !group.automatic) &&
          (this.args.everyone !== false || group.name !== "everyone") &&
          !exclude.has(group.id!) &&
          (!only || only.has(group.id!))
      )
      .map((group) => ({
        id: byName ? group.name : group.id,
        ...groupFields(group),
      }));
  }

  get legacyKind() {
    return this.args.legacyKind ?? "group-chooser";
  }

  get selectedValue() {
    assert(
      'DSelectGroup: @emit must be "names" or undefined',
      this.args.emit === undefined || this.args.emit === "names"
    );
    const values = makeArray(
      this.args.value as number | string | (number | string)[] | null
    );
    return this.args.multiple ? values : (values[0] ?? null);
  }

  @action
  onChange(value: SelectValue) {
    const values = makeArray(value) as (number | string)[];
    this.args.onChange?.(this.args.multiple ? values : (values[0] ?? null));
  }

  <template>
    {{! TODO (select-kit-replacement-cleanup): Retain the legacy family class during rollout. }}
    <DSelect
      ...attributes
      @ariaLabelledBy={{@ariaLabelledBy}}
      @clearable={{@clearable}}
      @describedBy={{@describedBy}}
      @disabled={{@disabled}}
      @icon={{@icon}}
      @id={{@id}}
      @identifier={{@identifier}}
      @instanceContext={{@instanceContext}}
      @invalid={{@invalid}}
      @items={{this.items}}
      @kind="select-group"
      @kindContext={{hash value=@value exclude=@exclude only=@only}}
      @kindTexts={{this.kindTexts}}
      @legacyKind={{this.legacyKind}}
      @maximum={{@maximum}}
      @maxVisibleChips={{@maxVisibleChips}}
      @multiple={{@multiple}}
      @onChange={{this.onChange}}
      @onClose={{@onClose}}
      @suppressFooter={{not (has-block "footer")}}
      @texts={{@texts}}
      @value={{this.selectedValue}}
      @variant={{@variant}}
    >
      <:item as |item options row|>
        {{#if (has-block "item")}}
          {{yield item options row to="item"}}
        {{else}}
          <GroupOption @item={{item}} />
        {{/if}}
      </:item>
      <:selection as |item options|>
        {{#if (has-block "selection")}}
          {{yield item options to="selection"}}
        {{else}}
          {{itemName item}}
        {{/if}}
      </:selection>
      <:footer as |state options|>
        {{yield state options to="footer"}}
      </:footer>
    </DSelect>
  </template>
}
