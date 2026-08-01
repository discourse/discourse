import ComposerPickerContent from "discourse/components/composer-picker/content";

const ComposerPickerDetached = <template>
  <ComposerPickerContent
    @close={{@close}}
    @term={{@data.term}}
    @initialTab={{@data.initialTab}}
    @onSelect={{@data.onSelect}}
    @context={{@data.context}}
    @composerEvents={{@data.composerEvents}}
  />
</template>;

export default ComposerPickerDetached;
