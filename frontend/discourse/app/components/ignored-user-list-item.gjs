import { fn } from "@ember/helper";
import DButton from "discourse/ui-kit/d-button";

const IgnoredUserListItem = <template>
  <div ...attributes>
    <div class="ignored-user-list-item">
      <span class="ignored-user-name">{{@item}}</span>
      <DButton
        class="remove-ignored-user no-text btn-icon"
        @action={{fn @onRemoveIgnoredUser @item}}
        @icon="xmark"
      />
    </div>
  </div>
</template>;

export default IgnoredUserListItem;
