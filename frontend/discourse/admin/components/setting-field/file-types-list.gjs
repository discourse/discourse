import { hash } from "@ember/helper";
import FileTypesList from "discourse/admin/components/site-settings/file-types-list";

const SettingFieldFileTypesList = <template>
  <@field.Control>
    <FileTypesList
      @allowAny={{not (eq @definition.allow_any false)}}
      @changeValueCallback={{@field.set}}
      @setting={{hash setting=@definition.key choices=@definition.choices}}
      @value={{@field.value}}
    />
  </@field.Control>
</template>;

export default SettingFieldFileTypesList;
