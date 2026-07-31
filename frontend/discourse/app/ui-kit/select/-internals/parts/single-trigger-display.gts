import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { on } from "@ember/modifier";
import booleanString from "discourse/helpers/boolean-string";
import { and, not, or } from "discourse/truth-helpers";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DSkeleton from "discourse/ui-kit/d-skeleton";
import type VariantPresenter from "discourse/ui-kit/select/-internals/coordinators/variant-presenter";
import keepAboveKeyboard from "discourse/ui-kit/select/-internals/modifiers/keep-above-keyboard";
import ComboboxQueryInput from "discourse/ui-kit/select/-internals/parts/combobox-query-input";
import SelectionLabel from "discourse/ui-kit/select/-internals/parts/selection-label";
import SelectEngine, {
  SelectItem,
  SelectLoadOptions,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

interface SingleTriggerDisplaySignature {
  Args: {
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
    /** Resolves the bound selection into its display item. */
    resolveSelection: (
      value: unknown,
      options?: SelectLoadOptions
    ) => SelectItem | Promise<SelectItem>;
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
    /** Custom markup for the selected item. */
    selection?: [
      /** The resolved selected item. */
      item: SelectItem,
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
      {{#unless @editing}}
        {{#if @presenter.isMobileTypeahead}}
          <span class="d-combobox__presentation">
            {{#if @engine.hasValue}}
              <DAsyncContent
                @asyncData={{@resolveSelection}}
                @context={{@value}}
              >
                <:loading><DSkeleton @variant="text" @width="8ch" /></:loading>
                <:content as |selected|>
                  {{#if @hasSelectionBlock}}
                    {{yield selected to="selection"}}
                  {{else}}
                    <SelectionLabel
                      @item={{selected}}
                      @labelField={{@presenter.labelField}}
                    />
                  {{/if}}
                </:content>
              </DAsyncContent>
            {{else}}
              <span class="d-combobox__placeholder">
                {{or @placeholder (i18n "d_select.placeholder")}}
              </span>
            {{/if}}
          </span>
        {{else if @hasSelectionBlock}}
          {{#if (and @engine.hasValue (not @triggerFocused))}}
            <span class="d-combobox__presentation" id={{@selectionId}}>
              <DAsyncContent
                @asyncData={{@resolveSelection}}
                @context={{@value}}
              >
                <:loading><DSkeleton @variant="text" @width="8ch" /></:loading>
                <:content as |selected|>{{yield
                    selected
                    to="selection"
                  }}</:content>
              </DAsyncContent>
            </span>
          {{/if}}
        {{else if @engine.hasValue}}
          <DAsyncContent @asyncData={{@resolveSelection}} @context={{@value}}>
            <:loading>
              <span class="d-combobox__presentation">
                <DSkeleton @variant="text" @width="8ch" />
              </span>
            </:loading>
            <:content></:content>
          </DAsyncContent>
        {{/if}}
      {{/unless}}
      {{#if @presenter.isDesktopTypeahead}}
        <ComboboxQueryInput
          @engine={{@engine}}
          @listboxId={{@listboxId}}
          @expanded={{@expanded}}
          @label={{@presenter.ariaLabelText}}
          {{! No placeholder once a value is chosen: the value is shown either in this input
            (default) or in the sibling selection presentation (with a :selection block),
            so a placeholder would otherwise sit next to it. }}
          @placeholder={{unless
            @engine.hasValue
            (or @placeholder (i18n "d_select.placeholder"))
          }}
          @displayValue={{if
            (and @hasSelectionBlock (not @triggerFocused))
            ""
            @presenter.fallbackSelectionLabel
          }}
          @selectLabelOnAppear={{@hasSelectionBlock}}
          @editing={{@editing}}
          @ariaOwns={{true}}
          @shouldSelectOnFocus={{@shouldSelectOnFocus}}
          @onOpen={{@showMenu}}
          @onRequestClose={{@closeMenu}}
          @onBlur={{@onBlur}}
          @onEdit={{@onEdit}}
          @registerInput={{@registerInput}}
          @disabled={{@presenter.isDisabled}}
          @readonly={{@presenter.isReadonly}}
          {{! Points at the sibling selection markup for exactly as long as that markup is
            what carries the value. Once focused the label moves into the input itself, so
            keeping the description would announce the selection twice. Mirrors the
            condition that renders the presentation span. }}
          id={{@id}}
          aria-invalid={{booleanString @invalid}}
          aria-describedby={{@composeDescribedBy
            (if
              (and @hasSelectionBlock @engine.hasValue (not @triggerFocused))
              @selectionId
            )
            @describedBy
          }}
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
        <:loading><DSkeleton @variant="text" @width="8ch" /></:loading>
        <:content as |selected|>
          <span class="d-combobox__value">
            {{#if @hasSelectionBlock}}
              {{yield selected to="selection"}}
            {{else}}
              <SelectionLabel
                @item={{selected}}
                @labelField={{@presenter.labelField}}
              />
            {{/if}}
          </span>
        </:content>
        <:empty>
          <span class="d-combobox__placeholder">
            {{or @placeholder (i18n "d_select.placeholder")}}
          </span>
        </:empty>
      </DAsyncContent>
    {{/if}}
  </template>;

export default SingleTriggerDisplay;
