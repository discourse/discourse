import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

const CollectionOptionRow = <template>
  <div
    class={{dConcatClass
      "workflows-property-engine__collection-row"
      (if @inlineControl "--inline-control")
    }}
    ...attributes
  >
    <DButton
      class="workflows-property-engine__collection-delete"
      @action={{@onRemove}}
      @icon="xmark"
      @translatedAriaLabel={{@removeLabel}}
      @translatedTitle={{@removeLabel}}
    />

    <div class="workflows-property-engine__collection-fields">
      {{yield}}
    </div>
  </div>
</template>;

export default CollectionOptionRow;
