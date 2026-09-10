import Component from "@glimmer/component";
import { action } from "@ember/object";
import Form from "discourse/components/form";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class VoiceKickModal extends Component {
  formData = { duration: "3600" };

  get durationOptions() {
    return [
      ["3600", "one_hour"],
      ["86400", "one_day"],
      ["604800", "one_week"],
      ["0", "indefinitely"],
    ].map(([value, label]) => ({
      value,
      label: i18n(`voice.participant.kick_modal.durations.${label}`),
    }));
  }

  @action
  confirm(data) {
    this.args.closeModal({ duration: Number(data.duration) });
  }

  <template>
    <DModal
      class="voice-kick-modal"
      @closeModal={{@closeModal}}
      @inline={{@inline}}
      @title={{i18n "voice.participant.kick_modal.title"}}
    >
      <:body>
        <Form @data={{this.formData}} @onSubmit={{this.confirm}} as |form|>
          <form.Field
            @name="duration"
            @title={{i18n "voice.participant.kick_modal.description"}}
            @type="select"
            @validation="required"
            as |field|
          >
            <field.Control @includeNone={{false}} as |control|>
              {{#each this.durationOptions as |option|}}
                <control.Option
                  @value={{option.value}}
                >{{option.label}}</control.Option>
              {{/each}}
            </field.Control>
          </form.Field>
          <form.Submit @label={{i18n "voice.participant.kick_modal.confirm"}} />
        </Form>
      </:body>
    </DModal>
  </template>
}
