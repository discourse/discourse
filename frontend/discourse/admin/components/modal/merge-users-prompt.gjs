import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, get, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import legacyPickOne from "discourse/lib/legacy-pick-one";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DSelectUser from "discourse/ui-kit/select/recipes/users/d-select-user";
import { i18n } from "discourse-i18n";

export default class MergeUsersPrompt extends Component {
  @service siteSettings;

  @tracked targetUsername;

  get mergeDisabled() {
    return (
      !this.targetUsername ||
      this.args.model.user.username === this.targetUsername[0]
    );
  }

  @action
  updateTargetUsername(targetUsername) {
    this.targetUsername = targetUsername;
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
        {{! TODO (select-kit-replacement-cleanup) }}
        {{#if this.siteSettings.enable_new_select_controls}}
          <DSelectUser
            @clearable={{true}}
            @onChange={{legacyPickOne this.updateTargetUsername}}
            @texts={{hash
              placeholder=(i18n
                "admin.user.merge.prompt.target_username_placeholder"
              )
              searchPlaceholder=(i18n
                "admin.user.merge.prompt.target_username_placeholder"
              )
            }}
            @value={{this.targetUsername}}
          />
        {{else}}
          {{! TODO (select-kit-replacement-cleanup) }}
          <EmailGroupUserChooser
            @onChange={{this.updateTargetUsername}}
            @options={{hash
              maximum=1
              filterPlaceholder="admin.user.merge.prompt.target_username_placeholder"
            }}
            @value={{this.targetUsername}}
          />
        {{/if}}
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
