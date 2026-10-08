import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { trustHTML } from "@ember/template";
import CreateInviteUploader from "discourse/components/create-invite-uploader";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

const CreateInviteBulk = <template>
  <CreateInviteUploader @autoFindInput={{false}} as |uploader setElement|>
    <DModal
      class="create-invite-bulk-modal --large"
      @closeModal={{@closeModal}}
      @title={{i18n "user.invited.bulk_invite.text"}}
    >
      <:body>
        {{#if uploader.uploaded}}
          {{i18n "user.invited.bulk_invite.success"}}
        {{else}}
          {{trustHTML (i18n "user.invited.bulk_invite.instructions")}}
          <input
            accept=".csv"
            disabled={{uploader.uploading}}
            id="csv-file"
            type="file"
            {{didInsert setElement}}
          />
        {{/if}}
      </:body>
      <:footer>
        {{#unless uploader.uploaded}}
          <DButton
            class="btn-primary"
            @action={{uploader.startUpload}}
            @disabled={{uploader.submitDisabled}}
            @icon="link"
            @translatedLabel={{if
              uploader.uploading
              (i18n
                "user.invited.bulk_invite.progress"
                progress=uploader.uploadProgress
              )
              (i18n "user.invited.bulk_invite.text")
            }}
          />
        {{/unless}}
        <DButton class="btn-primary" @action={{@closeModal}} @label="close" />
      </:footer>
    </DModal>
  </CreateInviteUploader>
</template>;

export default CreateInviteBulk;
