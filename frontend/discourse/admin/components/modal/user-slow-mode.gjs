import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class UserSlowModeModal extends Component {
  @tracked saving = false;

  @cached
  get data() {
    const state = this.args.model.user_slow_mode;
    return {
      minutes: state ? state.seconds / 60 : null,
      endsAt: state?.ends_at
        ? moment(state.ends_at).format("YYYY-MM-DDTHH:mm")
        : null,
    };
  }

  @action
  save({ minutes, endsAt }) {
    return this.#update(
      minutes * 60,
      endsAt ? new Date(endsAt).toISOString() : null
    );
  }

  @action
  remove() {
    return this.#update(0, null);
  }

  async #update(seconds, endsAt) {
    this.saving = true;
    try {
      const user = this.args.model;
      const response = await ajax(`/admin/users/${user.id}/slow_mode`, {
        type: "PUT",
        data: { seconds, ends_at: endsAt },
      });
      user.set("user_slow_mode", response.user_slow_mode);
      this.args.closeModal();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <DModal
      class="user-slow-mode-modal"
      @closeModal={{@closeModal}}
      @title={{i18n "admin.user.slow_mode.title"}}
    >
      <:body>
        <Form @data={{this.data}} @onSubmit={{this.save}} as |form|>
          <form.Field
            @name="minutes"
            @title={{i18n "admin.user.slow_mode.minutes"}}
            @type="input-number"
            @validation="required"
            as |field|
          >
            <field.Control max="10080" min="1" step="1" />
          </form.Field>

          <form.Field
            @name="endsAt"
            @title={{i18n "admin.user.slow_mode.ends_at"}}
            @type="input-datetime-local"
            as |field|
          >
            <field.Control />
          </form.Field>

          <form.Actions>
            <form.Submit @disabled={{this.saving}} @label="save" />
            {{#if @model.user_slow_mode}}
              <DButton
                @action={{this.remove}}
                @disabled={{this.saving}}
                @label="admin.user.slow_mode.remove"
              />
            {{/if}}
          </form.Actions>
        </Form>
      </:body>
    </DModal>
  </template>
}
