import TagsUploader from "discourse/admin/components/tags-uploader";
import routeAction from "discourse/helpers/route-action";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

const TagUpload = <template>
  <DModal @closeModal={{@closeModal}} @title={{i18n "tagging.upload"}}>
    <:body>
      <TagsUploader
        @closeModal={{@closeModal}}
        @id="tags-uploader"
        @refresh={{routeAction "triggerRefresh"}}
      />
    </:body>
  </DModal>
</template>;

export default TagUpload;
