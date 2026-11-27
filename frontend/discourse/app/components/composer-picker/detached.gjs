import ComposerPickerContent from "discourse/components/composer-picker/content";

const ComposerPickerDetached = <template>
  <ComposerPickerContent
    @close={{@close}}
    @composerEvents={{@data.composerEvents}}
    @context={{@data.context}}
    @initialTab={{@data.initialTab}}
    @onSelect={{@data.onSelect}}
    @term={{@data.term}}
  />
</template>;

export default ComposerPickerDetached;
