import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const EmptyImageState = <template>
  <div class="visual-editor-block-chrome__image-empty">
    {{dIcon "image"}}
    <span class="visual-editor-block-chrome__image-empty-label">
      {{i18n "visual_editor.canvas.image_empty_label"}}
    </span>
  </div>
</template>;

export default EmptyImageState;
