import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { makeArray } from "discourse/lib/helpers";
import { searchTagGroups } from "discourse/lib/tag-source";
import type SiteSettingsService from "discourse/services/site-settings";
import DSelect from "discourse/ui-kit/select/d-select";
import { tagItemName } from "discourse/ui-kit/select/recipes/tags/-internals/tag-renderers";
import type {
  SelectLoadOptions,
  SelectTexts,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";

/** The group picker's texts. */
const TAG_GROUP_TEXTS: SelectTexts = Object.freeze({
  placeholder: { key: "category.tag_groups_placeholder" },
});

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
    /** The picker's texts, over its defaults. */
    texts?: SelectSignature["Args"]["texts"];
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
    /** Accessible control name; it is never drawn. */
    ariaLabel?: string;
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

  kindTexts = TAG_GROUP_TEXTS;

  get selectionValue() {
    return this.args.multiple ? this.#value : (this.#value[0] ?? null);
  }

  get legacyKind() {
    return this.args.legacyKind ?? ["tag-group-chooser", "tag-chooser"];
  }

  get loadContext() {
    return { held: this.#value.join("|") };
  }

  get sourceLoad() {
    if (this.args.load) {
      return this.args.load;
    }
    return this.args.items ? undefined : this._load;
  }

  get valueItems() {
    return this.#value.map((name) => ({ id: name, name }));
  }

  /** The call site's texts, under which the old text arguments still apply. */
  get texts(): SelectTexts | undefined {
    const { ariaLabel, placeholder, texts } = this.args;
    if (!ariaLabel && !placeholder) {
      return texts;
    }
    return {
      ariaLabel: ariaLabel || undefined,
      placeholder: placeholder || undefined,
      ...Object.fromEntries(
        Object.entries(texts ?? {}).filter(([, text]) => text != null)
      ),
    };
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
  async _load(filter: string, opts: SelectLoadOptions) {
    const groups = await searchTagGroups(filter, {
      signal: opts.signal,
      siteSettings: this.siteSettings,
    });
    return this.args.multiple
      ? groups.filter((group) => !this.#value.includes(group.name))
      : groups;
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
      @kindTexts={{this.kindTexts}}
      @labelField="name"
      @legacyKind={{this.legacyKind}}
      @load={{this.sourceLoad}}
      @loadContext={{this.loadContext}}
      @maximum={{@maximum}}
      @maxVisibleChips={{@maxVisibleChips}}
      @multiple={{@multiple}}
      @onChange={{this.onChange}}
      @suppressFooter={{not (has-block "footer")}}
      @texts={{this.texts}}
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
