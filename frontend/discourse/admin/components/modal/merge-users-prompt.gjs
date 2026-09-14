import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, get, hash } from "@ember/helper";
import { trustHTML } from "@ember/template";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
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
      @closeModal={{@closeModal}}
      @title={{trustHTML
        (i18n "admin.user.merge.prompt.title" username=@model.user.username)
      }}
    >
      <:body>
        <p>
          {{trustHTML
            (i18n
              "admin.user.merge.prompt.description"
              username=@model.user.username
            )
          }}
        </p>
        <EmailGroupUserChooser
          @options={{hash
            maximum=1
            filterPlaceholder="admin.user.merge.prompt.target_username_placeholder"
          }}
          @value={{this.targetUsername}}
        />
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{fn
            @model.showMergeConfirmation
            (get this.targetUsername "0")
          }}
          @disabled={{this.mergeDisabled}}
          @icon="trash-can"
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
