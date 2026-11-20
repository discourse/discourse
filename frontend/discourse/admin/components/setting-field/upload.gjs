import { hash } from "@ember/helper";
import SiteSettingUpload from "discourse/admin/components/site-settings/upload";

const SettingFieldUpload = <template>
  <@field.Control>
    <SiteSettingUpload
      @changeValueCallback={{@field.set}}
      @disabled={{@field.disabled}}
      @setting={{hash
        setting=@definition.key
        authorized_extensions=@definition.authorized_extensions
        max_file_size_kb=@definition.max_file_size_kb
        upload=@definition.upload
      }}
      @value={{@field.value}}
    />
  </@field.Control>
</template>;

export default SettingFieldUpload;
