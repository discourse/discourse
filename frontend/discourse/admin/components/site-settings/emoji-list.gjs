import EmojiValueList from "discourse/admin/components/emoji-value-list";

const EmojiList = <template>
  <EmojiValueList
    @setting={{@setting}}
    @values={{@value}}
    @setValidationMessage={{@setValidationMessage}}
  />
</template>;

export default EmojiList;
