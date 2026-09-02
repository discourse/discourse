import EmojiValueList from "discourse/admin/components/emoji-value-list";

const EmojiList = <template>
  <EmojiValueList
    @changeValueCallback={{@changeValueCallback}}
    @setting={{@setting}}
    @setValidationMessage={{@setValidationMessage}}
    @values={{@value}}
  />
</template>;

export default EmojiList;
