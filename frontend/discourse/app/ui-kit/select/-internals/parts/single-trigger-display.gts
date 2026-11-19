import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { on } from "@ember/modifier";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DSkeleton from "discourse/ui-kit/d-skeleton";
import type VariantPresenter from "discourse/ui-kit/select/-internals/coordinators/variant-presenter";
import keepAboveKeyboard from "discourse/ui-kit/select/-internals/modifiers/keep-above-keyboard";
import ComboboxQueryInput from "discourse/ui-kit/select/-internals/parts/combobox-query-input";
import SelectionIcon from "discourse/ui-kit/select/-internals/parts/selection-icon";
import SelectionLabel from "discourse/ui-kit/select/-internals/parts/selection-label";
import SelectEngine, {
  SelectLoadRequest,
  SelectRecord,
  type SelectResolvedOption,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";

interface SingleTriggerDisplaySignature {
  Args: {
    /** Whether asynchronous selection work is pending. */
    pending: boolean;
    /** The current bound selection. */
    value?: SelectValue;
    /** The headless selection engine. */
    engine: SelectEngine;
    /** The stable helper for variant-specific presentation state. */
    presenter: VariantPresenter;
    /** The id of the currently rendered listbox. */
    listboxId?: string;
    /** Whether the menu is expanded. */
    expanded: boolean;
    /** The consumer's placeholder text. */
    placeholder?: string;
    /** Whether query editing has begun. */
    editing: boolean;
    /** Whether focus is inside the trigger input. */
    triggerFocused: boolean;
    /** The combobox element id. */
    id?: string;
    /** Whether the combobox is invalid. */
    invalid?: boolean;
    /** External description ids for the combobox. */
    describedBy?: string;
    /** Id of the resting selection presentation. */
    selectionId: string;
    /** Whether the consumer supplied custom selection markup. */
    hasSelectionBlock: boolean;
    /** Whether the consumer supplied custom markup for a selection that is still resolving. */
    hasSelectionLoadingBlock: boolean;
    /** Whether the consumer supplied custom markup for a held value that cannot be resolved. */
    hasUnresolvedBlock: boolean;
    /** Resolves the bound selection into its display record. */
    resolveSelection: (
      value: unknown,
      request?: SelectLoadRequest
    ) => SelectRecord | Promise<SelectRecord>;
    /** Composes the component and consumer description ids. */
    composeDescribedBy: (
      ...ids: Array<string | undefined | false>
    ) => string | undefined;
    /** Opens the menu. */
    showMenu: () => void;
    /** Closes the menu. */
    closeMenu: () => void;
    /** Determines whether focus should select the displayed label. */
    shouldSelectOnFocus: () => boolean;
    /** Handles focus leaving the desktop query input. */
    onBlur: (event: FocusEvent) => void;
    /** Handles query editing. */
    onEdit: () => void;
    /** Handles parsed pastes on the desktop query input. */
    onPaste: (event: ClipboardEvent) => void | Promise<void>;
    /** Captures the desktop query input. */
    registerInput: (element: HTMLElement) => void;
    /** Handles selection-removal keys on the query input. */
    onInputKeydown: (event: KeyboardEvent) => void;
    /** Handles focus entering the desktop query input. */
    onFocus: () => void;
    /** Whether the keyboard-occlusion correction should run. */
    shouldCorrectKeyboardOcclusion: () => boolean;
  };
  Blocks: {
    /** Custom markup for the selected record. */
    selection?: [
      /** The held option, as the select resolved it. */
      option: SelectResolvedOption,
    ];
    /** Custom markup shown in place of a selection while it resolves. */
    selectionLoading?: [];
    /** Custom markup for a held value that cannot be resolved. */
    unresolved?: [
      /** The held option the select could not resolve. */
      option: SelectResolvedOption,
    ];
  };
}

const SingleTriggerDisplay: TemplateOnlyComponent<SingleTriggerDisplaySignature> =
  <template>
    {{#if @presenter.isTypeahead}}
      {{! Composite box: [selection presentation] · [query input] · [caret]. The input
        displays either the selected-label fallback or the query; custom selection markup
        is a sibling, hidden from the first edit until close. A click anywhere on the
        trigger opens the overlay (DMenu's trigger-root click; onShow focuses the input).
        On mobile the query input lives in the modal (below), so tapping the trigger opens
        it there. }}
      {{! The held value's resolve stays mounted while the query is edited, so typing never
        aborts it; only what it shows is hidden. }}
      {{#if @presenter.isMobileTypeahead}}
        {{#if (or @pending @engine.hasValue)}}
          <DAsyncContent @asyncData={{@resolveSelection}} @context={{@value}}>
            <:loading>
              {{#unless @editing}}
                <span class="d-select__presentation">
                  {{~#if @hasSelectionLoadingBlock~}}
                    {{yield to="selectionLoading"}}
                  {{~else~}}
                    <DSkeleton @variant="text" @width="8ch" />
                  {{~/if~}}
                </span>
              {{/unless}}
            </:loading>
            <:content as |selected|>
              {{#unless @editing}}
                <span class="d-select__presentation">
                  {{#if selected}}
                    {{#unless @presenter.icon}}
                      <SelectionIcon @engine={{@engine}} @record={{selected}} />
                    {{/unless}}
                    {{#if (@engine.isHeldUnresolved selected)}}
                      {{#if @hasUnresolvedBlock}}
                        {{yield (@engine.heldOption selected) to="unresolved"}}
                      {{else}}
                        <SelectionLabel
                          @engine={{@engine}}
                          @record={{selected}}
                        />
                      {{/if}}
                    {{else if @hasSelectionBlock}}
                      {{yield (@engine.heldOption selected) to="selection"}}
                    {{else}}
                      <SelectionLabel
                        @engine={{@engine}}
                        @record={{selected}}
                      />
                    {{/if}}
                  {{/if}}
                </span>
              {{/unless}}
            </:content>
          </DAsyncContent>
        {{else if @presenter.heldNoneLabel}}
          {{#unless @editing}}
            <span class="d-select__presentation">
              {{@presenter.heldNoneLabel}}
            </span>
          {{/unless}}
        {{else if @placeholder}}
          {{#unless @editing}}
            <span class="d-select__presentation">
              <span class="d-select__placeholder">
                {{@placeholder}}
              </span>
            </span>
          {{/unless}}
        {{/if}}
      {{else if @hasSelectionBlock}}
        {{#if (or @pending @engine.hasValue)}}
          <DAsyncContent @asyncData={{@resolveSelection}} @context={{@value}}>
            <:loading>
              {{#if (and (not @editing) (or @pending (not @triggerFocused)))}}
                <span
                  class="d-select__presentation --beside-input"
                  id={{@selectionId}}
                >
                  {{~#if @hasSelectionLoadingBlock~}}
                    {{yield to="selectionLoading"}}
                  {{~else~}}
                    <DSkeleton @variant="text" @width="8ch" />
                  {{~/if~}}
                </span>
              {{/if}}
            </:loading>
            <:content as |selected|>
              {{! The label moves into the input on focus, so the icon stays beside it. }}
              {{#if selected}}
                {{#unless (or @editing @presenter.icon)}}
                  <SelectionIcon @engine={{@engine}} @record={{selected}} />
                {{/unless}}
              {{/if}}
              {{#if (and (not @editing) (or @pending (not @triggerFocused)))}}
                <span
                  class="d-select__presentation --beside-input"
                  id={{@selectionId}}
                >
                  {{#if selected}}
                    {{#if (@engine.isHeldUnresolved selected)}}
                      {{#if @hasUnresolvedBlock}}
                        {{yield (@engine.heldOption selected) to="unresolved"}}
                      {{else}}
                        <SelectionLabel
                          @engine={{@engine}}
                          @record={{selected}}
                        />
                      {{/if}}
                    {{else if @hasSelectionBlock}}
                      {{yield (@engine.heldOption selected) to="selection"}}
                    {{else}}
                      <SelectionLabel
                        @engine={{@engine}}
                        @record={{selected}}
                      />
                    {{/if}}
                  {{/if}}
                </span>
              {{/if}}
            </:content>
          </DAsyncContent>
        {{/if}}
      {{else if (or @pending @engine.hasValue)}}
        <DAsyncContent @asyncData={{@resolveSelection}} @context={{@value}}>
          <:loading>
            {{#unless @editing}}
              <span class="d-select__presentation">
                {{#if @hasSelectionLoadingBlock}}
                  {{yield to="selectionLoading"}}
                {{else}}
                  <DSkeleton @variant="text" @width="8ch" />
                {{/if}}
              </span>
            {{/unless}}
          </:loading>
          <:content as |selected|>
            {{! The label is the input's value, which is empty while a change is pending. }}
            {{#if selected}}
              {{#unless (or @editing @pending @presenter.icon)}}
                <SelectionIcon @engine={{@engine}} @record={{selected}} />
              {{/unless}}
            {{/if}}
          </:content>
        </DAsyncContent>
      {{/if}}
      {{#if @presenter.isDesktopTypeahead}}
        <ComboboxQueryInput
          aria-busy={{if @pending "true"}}
          aria-invalid={{if @invalid "true"}}
          id={{@id}}
          @ariaOwns={{true}}
          {{! Only the resting held value needs a description. Pending feedback can also
            render while focused, when the input must not describe that sibling. }}
          @describedBy={{@composeDescribedBy
            (if
              (and @hasSelectionBlock @engine.hasValue (not @triggerFocused))
              @selectionId
            )
            @describedBy
          }}
          @disabled={{@presenter.isDisabled}}
          @displayValue={{if
            (or
              @pending
              (and @hasSelectionBlock @engine.hasValue (not @triggerFocused))
            )
            ""
            @presenter.fallbackSelectionLabel
          }}
          @editing={{@editing}}
          @engine={{@engine}}
          @expanded={{@expanded}}
          @label={{@presenter.ariaLabelText}}
          @labelledBy={{@presenter.ariaLabelledBy}}
          @listboxId={{@listboxId}}
          @onBlur={{@onBlur}}
          @onEdit={{@onEdit}}
          @onOpen={{@showMenu}}
          @onRequestClose={{@closeMenu}}
          {{! No placeholder once a value is chosen: the value is shown either in this input
            (default) or in the sibling selection presentation (with a :selection block),
            so a placeholder would otherwise sit next to it. }}
          @placeholder={{unless
            (or @pending @presenter.showsValue)
            @placeholder
          }}
          @readonly={{@presenter.isReadonly}}
          @registerInput={{@registerInput}}
          @selectLabelOnAppear={{@hasSelectionBlock}}
          @shouldSelectOnFocus={{@shouldSelectOnFocus}}
          {{on "paste" @onPaste}}
          {{keepAboveKeyboard @shouldCorrectKeyboardOcclusion}}
          {{on "keydown" @onInputKeydown}}
          {{on "focus" @onFocus}}
        />
      {{/if}}
    {{else if @presenter.iconOnly}}
      {{! Icon-only trigger: the leading icon and caret (from TriggerFrame) are the whole
        control; the selected value and placeholder text are intentionally suppressed. }}
    {{else}}
      <DAsyncContent @asyncData={{@resolveSelection}} @context={{@value}}>
        <:loading>
          {{~#if @hasSelectionLoadingBlock~}}
            {{yield to="selectionLoading"}}
          {{~else~}}
            <DSkeleton @variant="text" @width="8ch" />
          {{~/if~}}
        </:loading>
        <:content as |selected|>
          {{#if selected}}
            <span class="d-select__value">
              {{#unless @presenter.icon}}
                <SelectionIcon @engine={{@engine}} @record={{selected}} />
              {{/unless}}
              {{#if (@engine.isHeldUnresolved selected)}}
                {{#if @hasUnresolvedBlock}}
                  {{yield (@engine.heldOption selected) to="unresolved"}}
                {{else}}
                  <SelectionLabel @engine={{@engine}} @record={{selected}} />
                {{/if}}
              {{else if @hasSelectionBlock}}
                {{yield (@engine.heldOption selected) to="selection"}}
              {{else}}
                <SelectionLabel @engine={{@engine}} @record={{selected}} />
              {{/if}}
            </span>
          {{/if}}
        </:content>
        <:empty>
          {{#if @presenter.heldNoneLabel}}
            <span class="d-select__value">
              {{@presenter.heldNoneLabel}}
            </span>
          {{else if @placeholder}}
            <span class="d-select__placeholder">
              {{@placeholder}}
            </span>
          {{/if}}
        </:empty>
      </DAsyncContent>
    {{/if}}
  </template>;

export default SingleTriggerDisplay;
