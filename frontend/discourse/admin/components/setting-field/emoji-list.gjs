import { fn } from "@ember/helper";
import EmojiValueList from "discourse/admin/components/emoji-value-list";
import showFieldError from "discourse/admin/lib/show-field-error";

const SettingFieldEmojiList = <template>
  <@field.Control>
    <EmojiValueList
      @changeValueCallback={{@field.set}}
      @settingName={{@definition.key}}
      @setValidationMessage={{fn showFieldError @field}}
      @values={{@field.value}}
    />
  </@field.Control>
</template>;

export default SettingFieldEmojiList;
