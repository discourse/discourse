import { avatarUrl, translateSize } from "discourse/lib/avatar-utils";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";

const avatarPx = translateSize("medium");

const IconAvatar = <template>
  <div class={{dConcatClass "icon-avatar" @data.classNames}}>
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
      {{dIcon @data.icon}}
    </div>
  </div>
</template>;

export default IconAvatar;
