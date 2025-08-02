import EmojiValueList from "admin/components/emoji-value-list";

const EmojiList = <template>
  <EmojiValueList
    @setting={{@setting}}
    @values={{@value}}
    @setValidationMessage={{@setValidationMessage}}
  />
</template>;

export default EmojiList;
