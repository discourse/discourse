import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { on } from "@ember/modifier";
import type { ModifierLike } from "@glint/template";
import DSkeleton from "discourse/ui-kit/d-skeleton";
import type { OptionsPresenter } from "discourse/ui-kit/select/-internals/coordinators/select-presenter-base";
import WindowedListCoordinator, {
  ListRow,
} from "discourse/ui-kit/select/-internals/coordinators/windowed-list-coordinator";
import SelectItem from "discourse/ui-kit/select/-internals/parts/select-item";
import SelectEngine, {
  SelectItem as SelectItemModel,
  selectItemLabel,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

interface SelectOptionRowSignature {
  Args: {
    /** The headless selection engine. */
    engine: SelectEngine;
    /** The stable helper for variant-specific presentation state. */
    presenter: OptionsPresenter;
    /** The windowed-list controller. */
    listbox: WindowedListCoordinator;
    /** Stable id of the panel's selection-limit message. */
    limitId: string;
    /** Icon marking selected rows. */
    selectedIcon?: string;
    /** Omits the selection marker, for a list that never shows a held row. */
    hideSelectionMarker?: boolean;
    /** Whether the select accepts multiple values. */
    multiple?: boolean;
    /** Whether the consumer supplied custom item markup. */
    hasItemBlock: boolean;
    /** Whether the consumer supplied custom placeholder-row markup. */
    hasSkeletonItemBlock: boolean;
    /** Whether the consumer supplied custom group-header markup. */
    hasGroupHeaderBlock: boolean;
    /** Handles pointer-down on an option before its click resolves. */
    onOptionMousedown: (event: MouseEvent) => void;
    /** The descriptor at this rendered slot, absent during window shrinkage. */
    descriptor?: ListRow;
    /** Complete rendered rows, used to identify the sticky boundary. */
    items: readonly ListRow[];
    /** Absolute row index. */
    index: number;
    /** Bound row positioning; applied before measurement. */
    place: ModifierLike<{ Element: HTMLElement }>;
    /** Bound row measurement. */
    measure: ModifierLike<{ Element: HTMLElement }>;
  };
  Blocks: {
    /** Custom markup for an item. */
    item?: [
      /** The item being rendered. */
      item: SelectItemModel,
    ];
    /** Custom markup for a group header. */
    groupHeader?: [
      /** The group-header item being rendered. */
      item: SelectItemModel,
    ];
    /** Custom markup for one placeholder row while a page of rows is loading. */
    skeletonItem?: [];
  };
}

const SelectOptionRow: TemplateOnlyComponent<SelectOptionRowSignature> =
  <template>
    {{! A windowed list can yield a row whose backing item briefly does not
            exist: when the items array shrinks, the virtualizer's last published
            window still references the old indices until it re-flushes. Render
            nothing for that transient slot rather than dereferencing an absent
            descriptor. }}
    {{#if @descriptor}}
      {{#let (@listbox.optionRow @descriptor) as |option|}}
        {{#if option.flags.group}}
          {{! A group header: presentational, so it is skipped by roving
                  navigation and carries no option position. }}
          <li
            class="d-select__group-header"
            data-option-key={{option.key}}
            role="presentation"
            {{@place}}
            {{@measure}}
          >
            {{#if @hasGroupHeaderBlock}}
              {{yield option.item to="groupHeader"}}
            {{/if}}
            <span hidden={{@hasGroupHeaderBlock}} id={{option.headerId}}>
              {{selectItemLabel option.item "label"}}
            </span>
          </li>
        {{else if option.flags.divider}}
          <li
            aria-hidden="true"
            class="d-select__divider"
            role="presentation"
            {{@place}}
            {{@measure}}
          ></li>
        {{else if option}}
          <SelectItem
            aria-disabled={{if
              (or @presenter.isLocked option.flags.disabled)
              "true"
            }}
            aria-posinset={{option.posInSet}}
            aria-setsize={{option.setSize}}
            data-index={{@index}}
            data-logical-index={{option.logicalIndex}}
            data-option-key={{option.key}}
            @active={{eq option.key @listbox.activeOptionKey}}
            @describedBy={{option.groupHeaderId}}
            @descriptor={{option}}
            @engine={{@engine}}
            @hideSelectionMarker={{@hideSelectionMarker}}
            @limitId={{@limitId}}
            @locked={{@presenter.isLocked}}
            @multiple={{@multiple}}
            @selectedIcon={{@selectedIcon}}
            @stickyEnd={{@listbox.isLastSticky @items @index}}
            {{@place}}
            {{@measure}}
            {{! Keep focus in the trigger input on pointer-select so the input
                does not blur-close the menu before the click resolves (needed for
                action rows, which keep the menu open). mousedown is required:
                blur fires before click; the handler no-ops for non-typeahead. }}
            {{! eslint-disable-next-line ember/template-no-pointer-down-event-binding }}
            {{on "mousedown" @onOptionMousedown}}
          >
            {{#if @hasItemBlock}}
              {{yield option.item to="item"}}
            {{else if option.flags.__create}}
              {{i18n
                "d_select.create_item"
                label=(selectItemLabel option.item @presenter.labelField)
              }}
            {{else}}
              {{selectItemLabel option.item @presenter.labelField}}
            {{/if}}
          </SelectItem>
        {{else}}
          {{! Frontier placeholder for an in-flight reveal: presentation, no
              posinset, so pending rows never enter the option set. }}
          <li
            aria-hidden="true"
            class="d-select__skeleton"
            role="presentation"
            {{@place}}
            {{@measure}}
          >
            {{#if @hasSkeletonItemBlock}}
              {{yield to="skeletonItem"}}
            {{else}}
              <DSkeleton @variant="text" />
            {{/if}}
          </li>
        {{/if}}
      {{/let}}
    {{/if}}
  </template>;

export default SelectOptionRow;
