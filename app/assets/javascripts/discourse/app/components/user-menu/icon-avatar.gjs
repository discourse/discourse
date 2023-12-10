import Component from "@glimmer/component";
import avatar from "discourse/helpers/bound-avatar-template";
import dIcon from "discourse-common/helpers/d-icon";

export default class IconAvatar extends Component {
  <template>
    <div class="icon-avatar">
      {{avatar @data.avatarTemplate "small"}}
      {{dIcon @data.icon}}
    </div>
  </template>
}
