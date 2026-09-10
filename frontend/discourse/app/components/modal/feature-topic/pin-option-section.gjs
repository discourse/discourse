import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import Form from "discourse/components/form";
import { FORMAT } from "discourse/select-kit/components/future-date-input-selector";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DFutureDateInput from "discourse/ui-kit/d-future-date-input";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export const MAX_GLOBALLY_PINNED_TOPICS = 4;

export default class PinOptionSection extends Component {
  @service dialog;

  @cached
  get formData() {
    return { pinUntil: this.args.dateValue };
  }

  @action
  validatePinUntil(name, value, { addError }) {
    const parsed = moment(value, FORMAT);
    if (!parsed.isValid() || parsed <= moment()) {
      addError(name, {
        title: i18n("topic.feature_topic.pin_until"),
        message: i18n("topic.feature_topic.pin_validation"),
      });
    }
  }

  @action
  handleDateSet(value, { set }) {
    set("pinUntil", value);
    this.args.onDateChange?.(value);
  }

  @action
  handleSubmit() {
    if (this.args.confirmMessage) {
      this.dialog.yesNoConfirm({
        message: this.args.confirmMessage,
        didConfirm: () => this.args.onPin(),
      });
    } else {
      this.args.onPin();
    }
  }

  <template>
    <Form
      class="feature-section"
      @data={{this.formData}}
      @onSubmit={{this.handleSubmit}}
      as |form|
    >
      <div class="feature-section__description">
        {{#if @statsMessage}}
          <p>
            <DConditionalLoadingSpinner @condition={{@loading}} @size="small">
              {{trustHTML @statsMessage}}
            </DConditionalLoadingSpinner>
          </p>
        {{/if}}

        <p>{{@noteMessage}}</p>
        <p class="feature-section__pin-message">{{trustHTML @pinMessage}}
          {{dIcon "far-clock"}}</p>

        <form.Field
          @name="pinUntil"
          @onSet={{this.handleDateSet}}
          @showTitle={{false}}
          @title={{i18n "topic.feature_topic.pin_until"}}
          @type="custom"
          @validate={{this.validatePinUntil}}
          as |field|
        >
          <field.Control>
            <DFutureDateInput
              class="pin-until"
              @clearable={{true}}
              @input={{field.value}}
              @onChangeInput={{field.set}}
            />
          </field.Control>
        </form.Field>

        <form.Submit @label={{@buttonLabel}} />
      </div>
    </Form>
  </template>
}
