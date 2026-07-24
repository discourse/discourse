import TagsUploader from "discourse/admin/components/tags-uploader";
import routeAction from "discourse/helpers/route-action";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

const TagUpload = <template>
  <DModal @title={{i18n "tagging.upload"}} @closeModal={{@closeModal}}>
    <:body>
      <TagsUploader
        @refresh={{routeAction "triggerRefresh"}}
        @closeModal={{@closeModal}}
        @id="tags-uploader"
      />
    </:body>
  </DModal>
</template>;

export default TagUpload;
