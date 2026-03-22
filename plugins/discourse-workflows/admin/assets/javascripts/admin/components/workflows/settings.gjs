import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

export default class WorkflowSettings extends Component {
  @service router;
  @service dialog;

  @action
  async deleteWorkflow() {
    await this.dialog.deleteConfirm({
      message: i18n("discourse_workflows.delete_confirm", {
        name: this.args.workflow.name,
      }),
      didConfirm: async () => {
        await this.args.workflow.destroyRecord();
        this.router.transitionTo("adminPlugins.show.discourse-workflows.index");
      },
    });
  }

  <template>
    <div class="workflows-settings">
      <section class="workflows-settings__section">
        <h3 class="workflows-settings__section-title">{{i18n
            "discourse_workflows.settings.danger_zone"
          }}</h3>
        <p class="workflows-settings__section-description">{{i18n
            "discourse_workflows.settings.delete_description"
          }}</p>
        <DButton
          @action={{this.deleteWorkflow}}
          @icon="trash-can"
          @label="discourse_workflows.delete"
          class="btn-danger btn-small"
        />
      </section>
    </div>
  </template>
}
