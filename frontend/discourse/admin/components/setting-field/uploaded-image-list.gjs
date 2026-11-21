import { hash } from "@ember/helper";
import UploadedImageList from "discourse/admin/components/site-settings/uploaded-image-list";

const SettingFieldUploadedImageList = <template>
  <@field.Control>
    <UploadedImageList
      @changeValueCallback={{@field.set}}
      @disabled={{@field.disabled}}
      @setting={{hash setting=@definition.key}}
      @value={{@field.value}}
    />
  </@field.Control>
</template>;

export default SettingFieldUploadedImageList;
