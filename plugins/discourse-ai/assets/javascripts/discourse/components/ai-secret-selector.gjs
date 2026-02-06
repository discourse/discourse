import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import ComboBox from "discourse/select-kit/components/combo-box";
import AiSecretCreateModal from "./modal/ai-secret-create-modal";

export default class AiSecretSelector extends Component {
  @service modal;

  get secretOptions() {
    return (this.args.secrets || []).map((s) => ({
      id: s.id,
      name: s.name,
    }));
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
          this.args.secrets?.pushObject?.(newSecret);
          this.args.onChange?.(newSecret.id);
        },
      },
    });
  }

  <template>
    <div class="ai-secret-selector">
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
    </div>
  </template>
}
