import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import { assertNoRemovedTextArgs } from "discourse/ui-kit/select/-internals/engine/select-texts";
import DSelect, {
  type DSelectSignature,
} from "discourse/ui-kit/select/d-select";
import type { SelectRecipeArgs } from "discourse/ui-kit/select/recipes/-internals/recipe-args";
import {
  renderSelectText,
  type SelectConfig,
  type SelectCoreTextKey,
  type SelectOption,
  selectOption,
  type SelectOptionLike,
  type SelectTexts,
  type SelectValue,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

/** A permission the picker offers. */
export interface PermissionRecord {
  id: string;
  name: string;
  /** What holding the permission allows. */
  description?: string;
}

/** The permission picker's arguments. */
interface DSelectPermissionSignature {
  Args: Pick<
    DSelectSignature["Args"],
    "ariaLabelledBy" | "describedBy" | "disabled" | "id"
  > &
    SelectRecipeArgs & {
      /** The permissions offered, as records or options. */
      options: readonly SelectOptionLike<PermissionRecord>[];
      /** The held permission's id. */
      value?: string | null;
      /** Offers Remove after the permissions; picking it calls this instead of changing the value. */
      onRemove?: () => void;
      /** The picker's texts, over its defaults: the engine's, `removeLabel` and `removeDescription`. */
      texts?: SelectTexts<
        SelectCoreTextKey | "removeLabel" | "removeDescription"
      >;
      /** Receives the picked permission's id. */
      onChange?: (permission: string) => void;
    };
  Element: HTMLElement;
}

const REMOVE_ID = "remove";

/** Picks one permission from a short list, optionally offering to remove the grant. */
export default class DSelectPermission extends Component<DSelectPermissionSignature> {
  kindTexts: SelectTexts = {
    ariaLabel: i18n("select_permission.permission"),
    removeLabel: i18n("access_control.manage.access_permission_remove"),
    removeDescription: i18n(
      "access_control.manage.access_permission_remove_description"
    ),
  };

  constructor(owner: Owner, args: DSelectPermissionSignature["Args"]) {
    super(owner, args);
    assertNoRemovedTextArgs("DSelectPermission", args);
  }

  /** The caller's permissions, each described by its record under the caller's settings. */
  @cached
  get options(): SelectOption<PermissionRecord>[] {
    return this.args.options.map((entry) => {
      const option = selectOption(entry);
      return option.with({
        description: option.record.description,
        ...option.settings,
      });
    });
  }

  @action
  extraOptions(
    _snapshot: unknown,
    config: SelectConfig
  ): SelectOption<PermissionRecord>[] {
    const onRemove = this.args.onRemove;
    if (!onRemove) {
      return [];
    }
    return [
      selectOption(
        { id: REMOVE_ID, name: renderSelectText(config, "removeLabel") },
        {
          position: "end",
          divider: "before",
          description: renderSelectText(config, "removeDescription"),
          onSelect: (control) => {
            control.close();
            onRemove();
          },
        }
      ),
    ];
  }

  @action
  onChange(value: SelectValue) {
    if (value != null) {
      this.args.onChange?.(value as string);
    }
  }

  <template>
    <DSelect
      ...attributes
      @ariaLabelledBy={{@ariaLabelledBy}}
      @describedBy={{@describedBy}}
      @disabled={{@disabled}}
      @extraOptions={{this.extraOptions}}
      @id={{@id}}
      @identifier={{@identifier}}
      @instanceContext={{@instanceContext}}
      @kind="select-permission"
      @kindTexts={{this.kindTexts}}
      @legacyKind={{@legacyKind}}
      @onChange={{this.onChange}}
      @options={{this.options}}
      @texts={{@texts}}
      @value={{@value}}
      @variant="static"
    />
  </template>
}
