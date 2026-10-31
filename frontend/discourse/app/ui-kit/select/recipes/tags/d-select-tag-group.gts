import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import { service } from "@ember/service";
import { makeArray } from "discourse/lib/helpers";
import { searchTagGroups } from "discourse/lib/tag-source";
import type SiteSettingsService from "discourse/services/site-settings";
import { assertNoRemovedTextArgs } from "discourse/ui-kit/select/-internals/engine/select-texts";
import DSelect from "discourse/ui-kit/select/d-select";
import { tagItemName } from "discourse/ui-kit/select/recipes/tags/-internals/tag-renderers";
import type {
  SelectCoreTexts,
  SelectTexts,
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
    /** Holds several groups; defaults to one, as DSelect does. */
    multiple?: boolean;
    /** Temporary compatibility aliases for legacy customizations and CSS. */
    legacyKind?: SelectSignature["Args"]["legacyKind"];
    /** Receives the selected group names in order. */
    onChange?: (names: string[] | string | null) => void;
    /** Maximum number of selected groups. */
    maximum?: number | false;
    /** The picker's texts, over its defaults. */
    texts?: SelectCoreTexts;
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
    /** Ids of visible captions that name the control, replacing the default name. */
    ariaLabelledBy?: string;
    /** Call-site customization identity. */
    identifier?: string;
    /** Call-site customization data. */
    instanceContext?: object;
  };
  Element: HTMLElement;
  Blocks: Pick<SelectSignature["Blocks"], "item" | "selection" | "footer">;
}

/** Searches tag groups; held groups stay listed, marked selected. */
export default class DSelectTagGroup extends Component<DSelectTagGroupSignature> {
  /** TODO(typescript-pending): Remove the extension when the settings factory exposes runtime keys. */
  @service
  declare siteSettings: SiteSettingsService & {
    max_tag_search_results: number;
  };

  /** The picker's texts: "Tag group" while it holds at most one, otherwise "Tag groups". */
  kindTexts: SelectTexts = {
    ariaLabel: (_values, context) =>
      context.multiple && this.args.maximum !== 1
        ? i18n("tagging.tag_groups_label")
        : i18n("tagging.tag_group_label"),
  };

  constructor(owner: Owner, args: DSelectTagGroupSignature["Args"]) {
    super(owner, args);
    assertNoRemovedTextArgs("DSelectTagGroup", args);
  }

  get selectionValue() {
    return this.args.multiple ? this.#value : (this.#value[0] ?? null);
  }

  get legacyKind() {
    return this.args.legacyKind ?? ["tag-group-chooser", "tag-chooser"];
  }

  get valueItems() {
    return this.#value.map((name) => ({ id: name, name }));
  }

  get #value() {
    const value = this.args.value;
    if (!value) {
      return [];
    }
    return [...new Set(makeArray(value as string | string[]))];
  }

  @action
  onChange(value: SelectValue) {
    if (this.args.multiple) {
      this.args.onChange?.(
        makeArray(value).filter(
          (name): name is string => typeof name === "string"
        )
      );
      return;
    }
    this.args.onChange?.(typeof value === "string" ? value : null);
  }

  @action
  async load(filter: string) {
    return await searchTagGroups(filter, {
      siteSettings: this.siteSettings,
    });
  }

  <template>
    {{! TODO (select-kit-replacement-cleanup): Retain the legacy family classes during rollout. }}
    <DSelect
      ...attributes
      @ariaLabelledBy={{@ariaLabelledBy}}
      @describedBy={{@describedBy}}
      @disabled={{@disabled}}
      @icon={{@icon}}
      @id={{@id}}
      @identifier={{@identifier}}
      @instanceContext={{@instanceContext}}
      @invalid={{@invalid}}
      @kind="select-tag-group"
      @kindContext={{hash value=@value}}
      @kindTexts={{this.kindTexts}}
      @labelField="name"
      @legacyKind={{this.legacyKind}}
      @load={{this.load}}
      @maximum={{@maximum}}
      @maxVisibleChips={{@maxVisibleChips}}
      @multiple={{@multiple}}
      @onChange={{this.onChange}}
      @suppressFooter={{not (has-block "footer")}}
      @texts={{@texts}}
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
