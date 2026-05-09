import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import Form from "discourse/components/form";
import FutureDateInput from "discourse/components/future-date-input";
import icon from "discourse/helpers/d-icon";
import { FORMAT } from "discourse/select-kit/components/future-date-input-selector";
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
      @data={{this.formData}}
      @onSubmit={{this.handleSubmit}}
      class="feature-section"
      as |form|
    >
      <div class="feature-section__description">
        {{#if @statsMessage}}
          <p>
            <ConditionalLoadingSpinner @size="small" @condition={{@loading}}>
              {{trustHTML @statsMessage}}
            </ConditionalLoadingSpinner>
          </p>
        {{/if}}

        <p>{{@noteMessage}}</p>
        <p class="feature-section__pin-message">{{trustHTML @pinMessage}}
          {{icon "far-clock"}}</p>

        <form.Field
          @name="pinUntil"
          @title={{i18n "topic.feature_topic.pin_until"}}
          @showTitle={{false}}
          @type="custom"
          @validate={{this.validatePinUntil}}
          @onSet={{this.handleDateSet}}
          as |field|
        >
          <field.Control>
            <FutureDateInput
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
