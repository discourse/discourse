import Component from "@glimmer/component";
import { concat, fn, hash } from "@ember/helper";
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
import { eq } from "discourse/truth-helpers";

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
  componentFor(component, field) {
    if (!component.controlType) {
      throw new Error(
        `Static property \`controlType\` is required on component:\n\n ${component}`
      );
    }

    return curryComponent(component, { field }, getOwner(this));
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
              {{#if field.showTitle}}
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
                {{yield
                  (hash
                    Custom=(this.componentFor FKControlCustom field)
                    Code=(this.componentFor FKControlCode field)
                    Question=(this.componentFor FKControlQuestion field)
                    Textarea=(this.componentFor FKControlTextarea field)
                    Checkbox=(this.componentFor FKControlCheckbox field)
                    Color=(this.componentFor FKControlColor field)
                    Image=(this.componentFor FKControlImage field)
                    Password=(this.componentFor FKControlPassword field)
                    Composer=(this.componentFor FKControlComposer field)
                    Icon=(this.componentFor FKControlIcon field)
                    Emoji=(this.componentFor FKControlEmoji field)
                    Toggle=(this.componentFor FKControlToggle field)
                    Menu=(this.componentFor FKControlMenu field)
                    Select=(this.componentFor FKControlSelect field)
                    TagChooser=(this.componentFor FKControlTagChooser field)
                    Input=(this.componentFor FKControlInput field)
                    RadioGroup=(this.componentFor FKControlRadioGroup field)
                    Calendar=(this.componentFor FKControlCalendar field)
                    errorId=field.errorId
                    id=field.id
                    name=field.name
                    set=field.set
                    value=field.value
                  )
                }}

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
