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

export default class FKField extends Component {
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
<<<<<<< HEAD
    <FKFieldData
      @name={{@name}}
      @data={{@data}}
      @emphasis={{@emphasis}}
      @triggerRevalidationFor={{@triggerRevalidationFor}}
      @title={{@title}}
      @tooltip={{@tooltip}}
      @description={{@description}}
      @helpText={{@helpText}}
      @showTitle={{@showTitle}}
      @collectionIndex={{@collectionIndex}}
      @set={{@set}}
      @addError={{@addError}}
      @validate={{@validate}}
      @validation={{@validation}}
      @onSet={{@onSet}}
      @registerField={{@registerField}}
      @format={{@format}}
      @titleFormat={{@titleFormat}}
      @descriptionFormat={{@descriptionFormat}}
      @disabled={{@disabled}}
      @parentName={{@parentName}}
      @placeholderUrl={{@placeholderUrl}}
      as |field|
    >
      {{#let
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
          emphasis=field.emphasis
          errorId=field.errorId
          id=field.id
          name=field.name
          set=field.set
          value=field.value
          isDirty=field.isDirty
          isPristine=field.isPristine
          rollback=field.rollback
          resetPatches=@data.resetPatches
        )
        as |yieldArgs|
      }}
        {{#if @size}}
          <FKRow as |row|>
            <row.Col @size={{@size}}>
              {{#if (has-block "body")}}
                {{yield yieldArgs to="body"}}
              {{else}}
                {{yield yieldArgs}}
              {{/if}}
            </row.Col>
          </FKRow>
        {{else}}
          {{#if (has-block "body")}}
            {{yield yieldArgs to="body"}}
          {{else}}
            {{yield yieldArgs}}
          {{/if}}
        {{/if}}
      {{/let}}
    </FKFieldData>
  </template>
}
