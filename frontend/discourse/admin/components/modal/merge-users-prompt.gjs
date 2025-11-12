import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, get, hash } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import { i18n } from "discourse-i18n";

export default class MergeUsersPrompt extends Component {
  @tracked targetUsername;

  get mergeDisabled() {
    return (
      !this.targetUsername ||
      this.args.model.user.username === this.targetUsername[0]
    );
  }

  <template>
    <DModal
      @title={{htmlSafe
        (i18n "admin.user.merge.prompt.title" username=@model.user.username)
      }}
      @closeModal={{@closeModal}}
    >
      <:body>
        <p>
          {{htmlSafe
            (i18n
              "admin.user.merge.prompt.description"
              username=@model.user.username
            )
          }}
        </p>
        <EmailGroupUserChooser
          @value={{this.targetUsername}}
          @options={{hash
            maximum=1
            filterPlaceholder="admin.user.merge.prompt.target_username_placeholder"
          }}
        />
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{fn
            @model.showMergeConfirmation
            (get this.targetUsername "0")
          }}
          @icon="trash-can"
          @disabled={{this.mergeDisabled}}
          @translatedLabel={{i18n
            "admin.user.merge.confirmation.transfer_and_delete"
            username=@model.user.username
          }}
        />
        <DButton
          @action={{@closeModal}}
          @label="admin.user.merge.prompt.cancel"
        />
      </:footer>
    </DModal>
  </template>
}
