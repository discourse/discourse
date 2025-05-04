import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import htmlSafe from "discourse/helpers/html-safe";
import { i18n } from "discourse-i18n";

export default class MergeUsersConfirmation extends Component {
  @tracked value;

  get mergeDisabled() {
    return !this.value || this.text !== this.value;
  }

  get text() {
    return i18n("admin.user.merge.confirmation.text", {
      username: this.args.model.username,
      targetUsername: this.args.model.targetUsername,
    });
  }

  <template>
    <DModal
      @title={{htmlSafe
        (i18n "admin.user.merge.confirmation.title" username=@model.username)
      }}
      @closeModal={{@closeModal}}
    >
      <:body>
        <p>
          {{htmlSafe
            (i18n
              "admin.user.merge.confirmation.description"
              username=@model.username
              targetUsername=@model.targetUsername
              text=this.text
            )
          }}
        </p>
        <Input @type="text" @value={{this.value}} />
      </:body>
      <:footer>
        <DButton
          class="btn-danger"
          @action={{fn @model.merge @model.targetUsername}}
          @icon="trash-can"
          @disabled={{this.mergeDisabled}}
          @translatedLabel={{i18n
            "admin.user.merge.confirmation.transfer_and_delete"
            username=@model.username
          }}
        />
        <DButton
          @action={{@closeModal}}
          @label="admin.user.merge.confirmation.cancel"
        />
      </:footer>
    </DModal>
  </template>
}
