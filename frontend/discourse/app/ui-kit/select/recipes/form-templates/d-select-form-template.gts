import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import { makeArray } from "discourse/lib/helpers";
import FormTemplate, {
  type FormTemplatePayload,
} from "discourse/models/form-template";
import DSelect, {
  type DSelectSignature,
} from "discourse/ui-kit/select/d-select";
import type { SelectRecipeArgs } from "discourse/ui-kit/select/recipes/-internals/recipe-args";
import type {
  SelectTexts,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

/** The form template picker's arguments. */
interface DSelectFormTemplateSignature {
  Args: Pick<
    DSelectSignature["Args"],
    | "ariaLabelledBy"
    | "ariaRequired"
    | "clearMode"
    | "describedBy"
    | "disabled"
    | "id"
    | "invalid"
    | "texts"
    | "variant"
  > &
    SelectRecipeArgs & {
      /** Limits the list to these templates. Without it, every template the user can see is offered. */
      formTemplateIds?: readonly number[];
      /** Holds several templates; defaults to one, as DSelect does. */
      multiple?: boolean;
      /** The held template's id, or the held ids when `@multiple`. */
      value?: number | readonly number[] | null;
      /** Receives the picked template's id, or every held id when `@multiple`. */
      onChange?: (value: number | number[] | null) => void;
    };
  Element: HTMLElement;
}

/**
 * Picks form templates by name. The server can't search them, so they are fetched once and
 * searched in the list.
 */
export default class DSelectFormTemplate extends Component<DSelectFormTemplateSignature> {
  /** The picker's texts; the engine's own wording covers the rest. */
  kindTexts: SelectTexts = {
    ariaLabel: (_values, context) =>
      context.multiple
        ? i18n("form_template_chooser.label_multiple")
        : i18n("form_template_chooser.label"),
    placeholder: (_values, context) =>
      context.multiple
        ? i18n("form_template_chooser.select_template")
        : undefined,
    noResults: () =>
      this.options.length ? undefined : i18n("form_template_chooser.none_yet"),
  };

  @tracked private _formTemplates: FormTemplatePayload[] = [];

  constructor(owner: Owner, args: DSelectFormTemplateSignature["Args"]) {
    super(owner, args);
    void this.#load();
  }

  /** The templates on offer, by name. */
  get options() {
    const ids = this.args.formTemplateIds;
    if (!ids) {
      return this._formTemplates;
    }
    return this._formTemplates.filter((template) => ids.includes(template.id));
  }

  get legacyKind() {
    return this.args.legacyKind ?? "form-template-chooser";
  }

  @action
  onChange(value: SelectValue) {
    if (this.args.multiple) {
      this.args.onChange?.(
        makeArray(value).filter((id): id is number => typeof id === "number")
      );
      return;
    }
    this.args.onChange?.(typeof value === "number" ? value : null);
  }

  async #load() {
    const formTemplates = await FormTemplate.findAll();
    if (this.isDestroying) {
      return;
    }
    this._formTemplates = formTemplates.sort((a, b) =>
      a.name.localeCompare(b.name)
    );
  }

  <template>
    <DSelect
      ...attributes
      @ariaLabelledBy={{@ariaLabelledBy}}
      @ariaRequired={{@ariaRequired}}
      @clearMode={{@clearMode}}
      @describedBy={{@describedBy}}
      @disabled={{@disabled}}
      @id={{@id}}
      @identifier={{@identifier}}
      @instanceContext={{@instanceContext}}
      @invalid={{@invalid}}
      @kind="select-form-template"
      @kindTexts={{this.kindTexts}}
      @legacyKind={{this.legacyKind}}
      @multiple={{@multiple}}
      @onChange={{this.onChange}}
      @options={{this.options}}
      @texts={{@texts}}
      @value={{@value}}
      @variant={{@variant}}
    />
  </template>
}
