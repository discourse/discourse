import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import curryComponent from "ember-curry-component";
import { modifier as modifierFn } from "ember-modifier";
import FKControlCalendar from "discourse/form-kit/components/fk/control/calendar";
import FKControlCheckbox from "discourse/form-kit/components/fk/control/checkbox";
import FKControlCode from "discourse/form-kit/components/fk/control/code";
import FKControlColor from "discourse/form-kit/components/fk/control/color";
import FKControlComposer from "discourse/form-kit/components/fk/control/composer";
import FKControlCustom from "discourse/form-kit/components/fk/control/custom";
import FKControlEmoji from "discourse/form-kit/components/fk/control/emoji";
import FKControlIcon from "discourse/form-kit/components/fk/control/icon";
import FKControlImage from "discourse/form-kit/components/fk/control/image";
import FKControlInput from "discourse/form-kit/components/fk/control/input";
import FKControlMenu from "discourse/form-kit/components/fk/control/menu";
import FKControlPassword from "discourse/form-kit/components/fk/control/password";
import FKControlQuestion from "discourse/form-kit/components/fk/control/question";
import FKControlRadioGroup from "discourse/form-kit/components/fk/control/radio-group";
import FKControlSelect from "discourse/form-kit/components/fk/control/select";
import FKControlTagChooser from "discourse/form-kit/components/fk/control/tag-chooser";
import FKControlTextarea from "discourse/form-kit/components/fk/control/textarea";
import FKControlToggle from "discourse/form-kit/components/fk/control/toggle";
import FKFieldData from "discourse/form-kit/components/fk/field-data";
import FKLabel from "discourse/form-kit/components/fk/label";
import FKMeta from "discourse/form-kit/components/fk/meta";
import FKOptional from "discourse/form-kit/components/fk/optional";
import FKRow from "discourse/form-kit/components/fk/row";
import FKText from "discourse/form-kit/components/fk/text";
import FKTooltip from "discourse/form-kit/components/fk/tooltip";
import concatClass from "discourse/helpers/concat-class";
import deprecated from "discourse/lib/deprecated";
import { and, eq, not } from "discourse/truth-helpers";

const RowColWrapper = <template>
  <FKRow as |row|>
    <row.Col @size={{@size}}>
      {{yield}}
    </row.Col>
  </FKRow>
</template>;

const EmptyWrapper = <template>
  {{! template-lint-disable no-yield-only }}
  {{yield}}
</template>;

export default class FKField extends Component {
  // Modifier for setting control type class/data-attribute.
  // Used by legacy path where type is set post-render by the control constructor.
  // Also runs on the new path where type is set via @type, will be removed when legacy path is removed.
  applyControlType = modifierFn((element, [field]) => {
    const type = field.type;

    if (type) {
      element.dataset.controlType = type;
      element.classList.add(`form-kit__field-${type}`);
    }
  });

  get wrapper() {
    if (this.args.size) {
      return RowColWrapper;
    } else {
      return EmptyWrapper;
    }
  }

  @action
  legacyComponentFor(component, field) {
    if (!component.controlType) {
      throw new Error(
        `Static property \`controlType\` is required on component:\n\n ${component}`
      );
    }

    return curryComponent(component, { field }, getOwner(this));
  }

  @action
  legacyYield(field) {
    deprecated(
      '<form.Field> without @type is deprecated. Use `<form.Field @type="..." as |field|><field.Control />` instead of `<form.Field as |field|><field.Input />`.',
      {
        id: "discourse.form-kit.legacy-field-yield",
        since: "2026.3",
      }
    );

    return {
      Custom: this.legacyComponentFor(FKControlCustom, field),
      Code: this.legacyComponentFor(FKControlCode, field),
      Question: this.legacyComponentFor(FKControlQuestion, field),
      Textarea: this.legacyComponentFor(FKControlTextarea, field),
      Checkbox: this.legacyComponentFor(FKControlCheckbox, field),
      Color: this.legacyComponentFor(FKControlColor, field),
      Image: this.legacyComponentFor(FKControlImage, field),
      Password: this.legacyComponentFor(FKControlPassword, field),
      Composer: this.legacyComponentFor(FKControlComposer, field),
      Icon: this.legacyComponentFor(FKControlIcon, field),
      Emoji: this.legacyComponentFor(FKControlEmoji, field),
      Toggle: this.legacyComponentFor(FKControlToggle, field),
      Menu: this.legacyComponentFor(FKControlMenu, field),
      Select: this.legacyComponentFor(FKControlSelect, field),
      TagChooser: this.legacyComponentFor(FKControlTagChooser, field),
      Input: this.legacyComponentFor(FKControlInput, field),
      RadioGroup: this.legacyComponentFor(FKControlRadioGroup, field),
      Calendar: this.legacyComponentFor(FKControlCalendar, field),
      errorId: field.errorId,
      id: field.id,
      name: field.name,
      set: field.set,
      get value() {
        return field.value;
      },
    };
  }

  <template>
    {{#let (curryComponent FKFieldData this.args) as |FieldData|}}
      <FieldData as |field|>
        <this.wrapper @size={{@size}}>
          {{#if (has-block-params)}}
            <div
              id={{concat "control-" field.normalizedName}}
              class={{concatClass
                "form-kit__container"
                "form-kit__field"
                (if field.type (concat "form-kit__field-" field.type))
                (if field.error "has-error")
                (if field.disabled "is-disabled")
                (if (eq field.format "full") "--full")
              }}
              data-disabled={{field.disabled}}
              data-name={{field.name}}
              {{this.applyControlType field}}
              {{didInsert (fn @registerField field.name field)}}
              {{willDestroy (fn @unregisterField field.name)}}
            >
              {{#if (and field.showTitle (not (eq field.type "checkbox")))}}
                <FKLabel
                  class={{concatClass
                    "form-kit__container-title"
                    (if field.titleFormat (concat "--" field.titleFormat))
                  }}
                  @fieldId={{field.id}}
                >
                  <span>{{field.title}}</span>

                  <FKOptional @field={{field}} />
                  <FKTooltip @field={{field}} />
                </FKLabel>
              {{/if}}

              {{#if field.description}}
                <FKText
                  class={{concatClass
                    "form-kit__container-description"
                    (if
                      field.descriptionFormat
                      (concat "--" field.descriptionFormat)
                    )
                  }}
                >{{field.description}}</FKText>
              {{/if}}

              <div
                class={{concatClass
                  "form-kit__container-content"
                  (if field.format (concat "--" field.format))
                }}
              >
                {{#if field.hasExplicitType}}
                  {{yield field}}
                {{else}}
                  {{yield (this.legacyYield field)}}
                {{/if}}

                {{#if field.helpText}}
                  <FKText
                    class="form-kit__container-help-text"
                  >{{field.helpText}}</FKText>
                {{/if}}

                <FKMeta @field={{field}} @error={{field.error}} />
              </div>
            </div>
          {{else}}
            {{yield}}
          {{/if}}
        </this.wrapper>
      </FieldData>
    {{/let}}
  </template>
}
