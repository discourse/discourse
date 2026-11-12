import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import { service } from "@ember/service";
import { makeArray } from "discourse/lib/helpers";
import { searchTagGroups } from "discourse/lib/tag-source";
import type SiteSettingsService from "discourse/services/site-settings";
import { assertNoRemovedTextArgs } from "discourse/ui-kit/select/-internals/engine/select-texts";
import DSelect, {
  type DSelectSignature,
} from "discourse/ui-kit/select/d-select";
import type { MultiSelectRecipeArgs } from "discourse/ui-kit/select/recipes/-internals/recipe-args";
import { tagRecordName } from "discourse/ui-kit/select/recipes/tags/-internals/tag-renderers";
import type {
  SelectCoreTexts,
  SelectTexts,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

/** Name-valued tag groups with single or multiple selection. */
interface DSelectTagGroupSignature {
  Args: MultiSelectRecipeArgs & {
    /** Held tag group names. */
    value?: readonly string[] | string | null;
    /** Holds several groups; defaults to one, as DSelect does. */
    multiple?: boolean;
    /** Receives the selected group names in order. */
    onChange?: (names: string[] | string | null) => void;
    /** Maximum number of selected groups. */
    maximum?: number | false;
    /** The picker's texts, over its defaults. */
    texts?: SelectCoreTexts;
    /** Trigger presentation. */
    variant?: DSelectSignature["Args"]["variant"];
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
  };
  Element: HTMLElement;
  Blocks: Pick<DSelectSignature["Blocks"], "option" | "selection" | "footer">;
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

  get valueRecords() {
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
      @lockedValues={{@lockedValues}}
      @maximum={{@maximum}}
      @maxVisibleChips={{@maxVisibleChips}}
      @multiple={{@multiple}}
      @onChange={{this.onChange}}
      @suppressFooter={{not (has-block "footer")}}
      @texts={{@texts}}
      @value={{this.selectionValue}}
      @valueRecords={{this.valueRecords}}
      @variant={{@variant}}
    >
      <:option as |record config option|>
        {{#if (has-block "option")}}
          {{yield record config option to="option"}}
        {{else}}
          {{tagRecordName record}}
        {{/if}}
      </:option>
      <:selection as |record config|>
        {{#if (has-block "selection")}}
          {{yield record config to="selection"}}
        {{else}}
          {{tagRecordName record}}
        {{/if}}
      </:selection>
      <:footer as |state config|>
        {{yield state config to="footer"}}
      </:footer>
    </DSelect>
  </template>
}
