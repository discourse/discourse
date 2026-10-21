import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { searchTagGroups } from "discourse/lib/tag-source";
import type SiteSettingsService from "discourse/services/site-settings";
import DSelect from "discourse/ui-kit/select/d-select";
import { tagItemName } from "discourse/ui-kit/select/recipes/tags/tag-select-base";
import type {
  SelectLoadOptions,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

/** Engine arguments shared by group chooser callers. */
type SelectSignature =
  DSelect extends Component<infer Signature> ? Signature : never;

/** Name-valued groups with a controlled array at every selection cap. */
interface DTagGroupChooserSignature {
  Args: {
    /** Held tag group names. */
    tagGroups?: readonly string[];
    /** Receives the selected group names in order. */
    onChange: (names: string[]) => void;
    /** Maximum number of selected groups. */
    maximum?: number;
    /** Translated placeholder for an empty selection. */
    placeholder?: string;
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
export default class DTagGroupChooser extends Component<DTagGroupChooserSignature> {
  /** TODO(typescript-pending): Remove the extension when the settings factory exposes runtime keys. */
  @service
  declare siteSettings: SiteSettingsService & {
    max_tag_search_results: number;
  };

  get value() {
    return [...new Set(this.args.tagGroups ?? [])];
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
    return groups.filter((group) => !this.value.includes(group.name));
  }

  @action
  onChange(value: SelectValue) {
    if (Array.isArray(value)) {
      this.args.onChange(
        value.filter((name): name is string => typeof name === "string")
      );
    }
  }

  <template>
    {{! TODO (select-kit-replacement-cleanup): Retain the legacy family classes during rollout. }}
    <DSelect
      class="tag-group-chooser tag-chooser"
      ...attributes
      @disabled={{@disabled}}
      @id={{@id}}
      @identifier={{@identifier}}
      @instanceContext={{@instanceContext}}
      @items={{@items}}
      @kind="tag-group-chooser"
      @kindContext={{hash tagGroups=@tagGroups}}
      @label={{@label}}
      @labelField="name"
      @load={{if @load @load this.load}}
      @loadContext={{this.loadContext}}
      @maximum={{@maximum}}
      @multiple={{true}}
      @onChange={{this.onChange}}
      @placeholder={{if
        @placeholder
        @placeholder
        (i18n "category.tag_groups_placeholder")
      }}
      @value={{this.value}}
      @valueItems={{this.valueItems}}
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
