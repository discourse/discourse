import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import ComboBox from "discourse/select-kit/components/combo-box";
import AiSecretCreateModal from "./modal/ai-secret-create-modal";

export default class AiSecretSelector extends Component {
  @service modal;

  @tracked addedSecrets = [];

  get secretOptions() {
    return [...(this.args.secrets || []), ...this.addedSecrets].map((s) => ({
      id: s.id,
      name: s.name,
    }));
  }

  get hasSecrets() {
    return this.secretOptions.length > 0;
  }

  @action
  onSelectSecret(secretId) {
    this.args.onChange?.(secretId);
  }

  @action
  openCreateModal() {
    this.modal.show(AiSecretCreateModal, {
      model: {
        onSave: (newSecret) => {
          this.addedSecrets = [...this.addedSecrets, newSecret];
          this.args.onChange?.(newSecret.id);
        },
      },
    });
  }

  <template>
    <div class="ai-secret-selector">
      {{#if this.hasSecrets}}
        <ComboBox
          @value={{@value}}
          @content={{this.secretOptions}}
          @onChange={{this.onSelectSecret}}
          @options={{hash
            filterable=true
            none="discourse_ai.secrets.select_secret"
          }}
          class="ai-secret-selector__dropdown"
        />
        <DButton
          @action={{this.openCreateModal}}
          @icon="plus"
          @title="discourse_ai.secrets.create_new"
          class="btn-default ai-secret-selector__add-btn"
        />
      {{else}}
        <DButton
          @action={{this.openCreateModal}}
          @icon="plus"
          @label="discourse_ai.secrets.add_secret"
          class="btn-default ai-secret-selector__add-btn"
        />
      {{/if}}
    </div>
  </template>
}
