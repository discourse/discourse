import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AdminCreateLeaderboard extends Component {
  @service currentUser;
  @service router;
  @service toasts;

  @tracked loading = false;

  get formData() {
    return { name: "", created_by_id: this.currentUser.id };
  }

  @action
  async createNewLeaderboard(data) {
    if (this.loading) {
      return;
    }

    this.loading = true;

    try {
      const leaderboard = await ajax(
        "/admin/plugins/gamification/leaderboard",
        {
          data,
          type: "POST",
        }
      );
      this.toasts.success({
        duration: "short",
        data: {
          message: i18n("gamification.leaderboard.create_success"),
        },
      });
      this.router.transitionTo(
        "adminPlugins.show.discourse-gamification-leaderboards.edit",
        leaderboard.id
      );
    } catch (err) {
      popupAjaxError(err);
    } finally {
      this.loading = false;
    }
  }

  @action
  cancel() {
    this.router.transitionTo(
      "adminPlugins.show.discourse-gamification-leaderboards"
    );
  }

  <template>
    <Form
      class="new-leaderboard-form"
      @data={{this.formData}}
      @onSubmit={{this.createNewLeaderboard}}
      as |form|
    >
      <form.Field
        class="new-leaderboard__name"
        @name="name"
        @title={{i18n "gamification.leaderboard.name"}}
        @type="input"
        @validation="required"
        as |field|
      >
        <field.Control
          placeholder={{i18n "gamification.leaderboard.name_placeholder"}}
        />
      </form.Field>

      <form.Actions>
        <form.Submit />

        <form.Button
          class="new-leaderboard__cancel btn-default"
          @action={{this.cancel}}
          @label="gamification.cancel"
        />
      </form.Actions>
    </Form>
  </template>
}
