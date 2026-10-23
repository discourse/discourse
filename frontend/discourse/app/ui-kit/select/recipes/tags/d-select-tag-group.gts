import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { searchTagGroups } from "discourse/lib/tag-source";
import type SiteSettingsService from "discourse/services/site-settings";
import DSelect from "discourse/ui-kit/select/d-select";
import { tagItemName } from "discourse/ui-kit/select/recipes/tags/-internals/tag-select-base";
import type {
  SelectLoadOptions,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

/** Engine arguments shared by group chooser callers. */
type SelectSignature =
  DSelect extends Component<infer Signature> ? Signature : never;

/** Name-valued tag groups with single or multiple selection. */
interface DSelectTagGroupSignature {
  Args: {
    /** Held tag group names. */
    value?: readonly string[] | string | null;
    /** Multiple selection defaults to true. */
    multiple?: boolean;
    /** Temporary compatibility aliases for legacy customizations and CSS. */
    legacyKind?: SelectSignature["Args"]["legacyKind"];
    /** Receives the selected group names in order. */
    onChange?: (names: string[] | string | null) => void;
    /** Maximum number of selected groups. */
    maximum?: number | false;
    /** Translated placeholder for an empty selection. */
    placeholder?: string;
    /** Trigger presentation. */
    variant?: SelectSignature["Args"]["variant"];
    /** Maximum visible chips before the count badge. */
    maxVisibleChips?: number;
    /** Icon displayed at the start of the trigger. */
    icon?: string;
    /** Persistent help element ids. */
    describedBy?: string;
    /** Marks the selection invalid for surrounding form validation. */
    invalid?: boolean;
    /** Prevent opening or selecting. */
    disabled?: boolean;
    /** External label target. */
    id?: string;
    /** Accessible control label. */
    label?: string;
    /** Call-site customization identity. */
    identifier?: string;
    /** Call-site customization data. */
    instanceContext?: object;
    /** Optional local source. */
    items?: SelectSignature["Args"]["items"];
    /** Optional asynchronous source override. */
    load?: SelectSignature["Args"]["load"];
  };
  Element: HTMLElement;
  Blocks: Pick<SelectSignature["Blocks"], "item" | "selection" | "footer">;
}

/** Searches tag groups, excluding held names from the results. */
export default class DSelectTagGroup extends Component<DSelectTagGroupSignature> {
  /** TODO(typescript-pending): Remove the extension when the settings factory exposes runtime keys. */
  @service
  declare siteSettings: SiteSettingsService & {
    max_tag_search_results: number;
  };

  get value() {
    const value = this.args.value;
    return [
      ...new Set(Array.isArray(value) ? value : value ? [value as string] : []),
    ];
  }

  get multiple() {
    return this.args.multiple !== false;
  }

  get selectionValue() {
    return this.multiple ? this.value : (this.value[0] ?? null);
  }

  get legacyKind() {
    return this.args.legacyKind ?? ["tag-group-chooser", "tag-chooser"];
  }

  get loadContext() {
    return { held: this.value.join("|") };
  }

  get valueItems() {
    return this.value.map((name) => ({ id: name, name }));
  }

  @action
  async load(filter: string, opts: SelectLoadOptions) {
    const groups = await searchTagGroups(filter, {
      signal: opts.signal,
      siteSettings: this.siteSettings,
    });
    return this.multiple
      ? groups.filter((group) => !this.value.includes(group.name))
      : groups;
  }

  @action
  onChange(value: SelectValue) {
    this.args.onChange?.(
      this.multiple
        ? Array.isArray(value)
          ? value.filter((name): name is string => typeof name === "string")
          : []
        : typeof value === "string"
          ? value
          : null
    );
  }

  <template>
    {{! TODO (select-kit-replacement-cleanup): Retain the legacy family classes during rollout. }}
    <DSelect
      ...attributes
      @describedBy={{@describedBy}}
      @disabled={{@disabled}}
      @icon={{@icon}}
      @id={{@id}}
      @identifier={{@identifier}}
      @instanceContext={{@instanceContext}}
      @invalid={{@invalid}}
      @items={{@items}}
      @kind="select-tag-group"
      @kindContext={{hash value=@value}}
      @label={{@label}}
      @labelField="name"
      @legacyKind={{this.legacyKind}}
      @load={{if @load @load (if @items undefined this.load)}}
      @loadContext={{this.loadContext}}
      @maximum={{@maximum}}
      @maxVisibleChips={{@maxVisibleChips}}
      @multiple={{this.multiple}}
      @onChange={{this.onChange}}
      @placeholder={{if
        @placeholder
        @placeholder
        (i18n "category.tag_groups_placeholder")
      }}
      @value={{this.selectionValue}}
      @valueItems={{this.valueItems}}
      @variant={{@variant}}
    >
      <:item as |item options|>
        {{#if (has-block "item")}}
          {{yield item options to="item"}}
        {{else}}
          {{tagItemName item}}
        {{/if}}
      </:item>
      <:selection as |item options|>
        {{#if (has-block "selection")}}
          {{yield item options to="selection"}}
        {{else}}
          {{tagItemName item}}
        {{/if}}
      </:selection>
      <:footer as |state options|>
        {{yield state options to="footer"}}
      </:footer>
    </DSelect>
  </template>
}
