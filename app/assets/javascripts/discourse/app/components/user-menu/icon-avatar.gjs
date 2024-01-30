import avatar from "discourse/helpers/bound-avatar-template";
import icon from "discourse-common/helpers/d-icon";

const IconAvatar = <template>
  <div class="icon-avatar">
    {{avatar @data.avatarTemplate "small"}}
    <div class="icon-avatar__icon-wrapper">
      {{icon @data.icon}}
    </div>
  </div>
</template>;

export default IconAvatar;
