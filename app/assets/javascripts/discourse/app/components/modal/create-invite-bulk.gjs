import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import CreateInviteUploader from "discourse/components/create-invite-uploader";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import htmlSafe from "discourse/helpers/html-safe";
import i18n from "discourse/helpers/i18n";

const CreateInviteBulk = <template>
  <CreateInviteUploader @autoFindInput={{false}} as |uploader setElement|>
    <DModal
      @title={{i18n "user.invited.bulk_invite.text"}}
      class="create-invite-bulk-modal -large"
      @closeModal={{@closeModal}}
    >
      <:body>
        {{#if uploader.uploaded}}
          {{i18n "user.invited.bulk_invite.success"}}
        {{else}}
          {{htmlSafe (i18n "user.invited.bulk_invite.instructions")}}
          <input
            id="csv-file"
            disabled={{uploader.uploading}}
            type="file"
            accept=".csv"
            {{didInsert setElement}}
          />
        {{/if}}
      </:body>
      <:footer>
        {{#unless uploader.uploaded}}
          <DButton
            @icon="link"
            @translatedLabel={{if
              uploader.uploading
              (i18n
                "user.invited.bulk_invite.progress"
                progress=uploader.uploadProgress
              )
              (i18n "user.invited.bulk_invite.text")
            }}
            class="btn-primary"
            @action={{uploader.startUpload}}
            @disabled={{uploader.submitDisabled}}
          />
        {{/unless}}
        <DButton @label="close" class="btn-primary" @action={{@closeModal}} />
      </:footer>
    </DModal>
  </CreateInviteUploader>
</template>;
export default CreateInviteBulk;
