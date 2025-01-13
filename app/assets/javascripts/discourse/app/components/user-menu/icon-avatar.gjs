import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { avatarUrl, translateSize } from "discourse-common/lib/avatar-utils";

const avatarPx = translateSize("medium");

const IconAvatar = <template>
  <div class={{concatClass "icon-avatar" @data.classNames}}>
    {{!--
        avoiding {{avatar}} helper because its html would be fully
        re-rendered whenever arguments change, even if the argument values
        are identical. On some browsers, re-rendering a lazy-loaded image
        causes a visible flicker.
      --}}
    <img
      lazy="lazy"
      src={{avatarUrl @data.avatarTemplate "medium"}}
      width={{avatarPx}}
      height={{avatarPx}}
      class="avatar"
    />
    <div class="icon-avatar__icon-wrapper">
      {{icon @data.icon}}
    </div>
  </div>
</template>;

export default IconAvatar;
