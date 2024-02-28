import avatar from "discourse/helpers/bound-avatar-template";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse-common/helpers/d-icon";

const IconAvatar = <template>
  <div class={{concatClass "icon-avatar" @data.classNames}}>
    {{avatar @data.avatarTemplate "small"}}
    <div class="icon-avatar__icon-wrapper">
      {{icon @data.icon}}
    </div>
  </div>
</template>;

export default IconAvatar;
