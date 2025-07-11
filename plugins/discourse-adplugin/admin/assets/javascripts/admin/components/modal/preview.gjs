import { htmlSafe } from "@ember/template";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";

const Preview = <template>
  <DModal
    @closeModal={{@closeModal}}
    @title={{i18n "admin.adplugin.house_ads.preview"}}
  >
    <:body>
      <div class="house-ad-preview">
        {{htmlSafe @model.html}}
      </div>
    </:body>
  </DModal>
</template>;

export default Preview;
