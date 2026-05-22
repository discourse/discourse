import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const EmptyImageState = <template>
  <div class="wireframe-block-chrome__image-empty">
    <div class="wireframe-block-chrome__image-empty-content">
      {{dIcon "image"}}
      <span class="wireframe-block-chrome__image-empty-label">
        {{i18n "wireframe.canvas.image_empty_label"}}
      </span>
    </div>
  </div>
</template>;

export default EmptyImageState;
