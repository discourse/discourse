import EmojiValueList from "discourse/admin/components/emoji-value-list";

const EmojiList = <template>
  <EmojiValueList
    @setting={{@setting}}
    @values={{@value}}
    @setValidationMessage={{@setValidationMessage}}
    @changeValueCallback={{@changeValueCallback}}
  />
</template>;

export default EmojiList;
