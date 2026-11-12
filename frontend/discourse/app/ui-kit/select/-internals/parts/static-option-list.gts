import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { warn } from "@ember/debug";
import type { ModifierLike } from "@glint/template";
import { modifier as createModifier } from "ember-modifier";
import DSkeleton from "discourse/ui-kit/d-skeleton";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import type SelectAnnouncer from "discourse/ui-kit/select/-internals/coordinators/select-announcer";
import type { OptionsPresenter } from "discourse/ui-kit/select/-internals/coordinators/select-presenter-base";
import WindowedListCoordinator, {
  ListRow,
} from "discourse/ui-kit/select/-internals/coordinators/windowed-list-coordinator";
import type { SelectListModifiers } from "discourse/ui-kit/select/-internals/parts/select-list-body";
import SelectOptionRow from "discourse/ui-kit/select/-internals/parts/select-option-row";
import SelectEngine, {
  type SelectGroupInfo,
  type SelectOption,
  SelectRecord as SelectRecordModel,
} from "discourse/ui-kit/select/select-engine";

interface StaticOptionListSignature {
  Args: {
    /** The headless selection engine. */
    engine: SelectEngine;
    /** The stable helper for variant-specific presentation state. */
    presenter: OptionsPresenter;
    /** The windowed-list controller. */
    listbox: WindowedListCoordinator;
    /** The stable helper for screen-reader announcements. */
    announcer: SelectAnnouncer;
    /** Explicit listbox tab index for persistent hosts. */
    tabIndex?: number;
    /** The rendered listbox id. */
    listboxId: string;
    /** Stable id of the panel's selection-limit message. */
    limitId?: string;
    /** Icon marking selected rows. */
    selectedIcon?: string;
    /** Omits the selection marker, for a list that never shows a held row. */
    hideSelectionMarker?: boolean;
    /** Whether the select accepts multiple values. */
    multiple?: boolean;
    /** Accessible label for the listbox. */
    label?: string;
    /** Ids of the elements naming the listbox, used instead of `label`. */
    labelledBy?: string;
    /** Whether the consumer supplied custom option markup. */
    hasOptionBlock: boolean;
    /** Whether the consumer supplied custom placeholder-row markup. */
    hasSkeletonBlock: boolean;
    /** Whether the consumer supplied custom group-header markup. */
    hasGroupHeaderBlock: boolean;
    /** Whether the consumer supplied custom group-footer markup. */
    hasGroupFooterBlock: boolean;
    /** Handles pointer-down on an option before its click resolves. */
    onOptionMousedown: (event: MouseEvent) => void;
    /** Composed rows for this resolved content. */
    items: readonly ListRow[];
    /** Shared modifiers from the async shell. */
    modifiers: SelectListModifiers;
  };
  Blocks: {
    /** Custom markup for an option. */
    option?: [
      /** The record the option stands for. */
      record: SelectRecordModel,
      /** The option, with its settings. */
      option: SelectOption,
    ];
    /** Custom markup for a group header. */
    groupHeader?: [
      /** The header's record. */
      record: SelectRecordModel,
      /** The group the header belongs to. */
      group: SelectGroupInfo,
    ];
    /** Custom markup for a group footer. */
    groupFooter?: [
      /** The footer's record. */
      record: SelectRecordModel,
      /** The group the footer belongs to. */
      group: SelectGroupInfo,
    ];
    /** Custom markup for one placeholder row while a page of rows is loading. */
    skeleton?: [];
  };
}

/** Static rows need neither positioning nor measurement. */
const inFlow: ModifierLike<{ Element: HTMLElement }> = createModifier(() => {});

/** Static lists deliberately stop at their first page. */
const warnPagination = createModifier(
  (_element: HTMLElement, [engine]: [SelectEngine]) => {
    warn(
      "DSelectList: @virtualized={{false}} does not paginate; only the loaded page is shown.",
      !engine.canRevealMore &&
        !(engine.total != null && engine.total > engine.loadedCount),
      { id: "discourse.d-select-list.static-pagination" }
    );
  }
);

const StaticOptionList: TemplateOnlyComponent<StaticOptionListSignature> =
  <template>
    <ul
      aria-busy={{if @engine.serverPending "true" "false"}}
      aria-label={{unless @labelledBy @label}}
      aria-labelledby={{@labelledBy}}
      aria-multiselectable={{if @multiple "true"}}
      class="d-select__listbox d-select__options"
      id={{@listboxId}}
      role="listbox"
      tabindex="-1"
      {{warnPagination @engine}}
      {{@modifiers.register}}
      {{@modifiers.release}}
      {{@modifiers.recordOnEntry}}
      {{@modifiers.record}}
      {{@modifiers.countOnEntry}}
      {{@modifiers.count}}
      {{@modifiers.roving}}
    >
      {{#each @items key="key" as |descriptor index|}}
        {{#if descriptor.isSkeleton}}
          {{! The row's own marker slot and label stay in flow but invisible, so the placeholder
            keeps the row's size and the list does not reflow under the skeleton. }}
          <li aria-hidden="true" class="d-select__option --placeholder">
            {{#unless @hideSelectionMarker}}
              {{dIcon
                "far-square"
                class="d-select__option-selected-icon --checkbox"
              }}
            {{/unless}}
            <span class="d-select__placeholder-label">
              {{~descriptor.label~}}
            </span>
            <DSkeleton @variant="text" />
          </li>
        {{else}}
          <SelectOptionRow
            @descriptor={{descriptor}}
            @engine={{@engine}}
            @hasGroupFooterBlock={{false}}
            @hasGroupHeaderBlock={{false}}
            @hasOptionBlock={{@hasOptionBlock}}
            @hasSkeletonBlock={{false}}
            @hideSelectionMarker={{@hideSelectionMarker}}
            @index={{index}}
            @items={{@items}}
            @limitId={{@limitId}}
            @listbox={{@listbox}}
            @measure={{inFlow}}
            @multiple={{@multiple}}
            @onOptionMousedown={{@onOptionMousedown}}
            @place={{inFlow}}
            @presenter={{@presenter}}
            @selectedIcon={{@selectedIcon}}
          >
            <:option as |record option|>
              {{~yield record option to="option"~}}
            </:option>
          </SelectOptionRow>
        {{/if}}
      {{/each}}
    </ul>
  </template>;

export default StaticOptionList;
