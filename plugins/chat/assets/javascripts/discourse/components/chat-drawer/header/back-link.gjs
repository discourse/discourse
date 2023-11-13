import Component from "@glimmer/component";
import { array } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { inject as service } from "@ember/service";
import dIcon from "discourse-common/helpers/d-icon";
import or from "truth-helpers/helpers/or";

export default class ChatDrawerHeaderBackLink extends Component {
  @service chatStateManager;

  <template>
    <LinkTo
      title={{@title}}
      class="chat-drawer-header__back-btn"
      @route={{@route}}
      @models={{or @routeModels (array)}}
    >
      {{dIcon "chevron-left"}}
    </LinkTo>
  </template>
}
