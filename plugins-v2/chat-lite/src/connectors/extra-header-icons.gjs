import Component from "@glimmer/component";
import { service } from "discourse-plugin/services";
import HeaderIcon from "../components/header-icon.gjs";
import ChatService from "../services/chat.js";

export default class ExtraHeaderIcon extends Component {
  @service(ChatService) chat;

  <template>
    {{#if this.chat.userCanChat}}
      <li class="header-dropdown-toggle chat-header-icon">
        <div class="widget-component-connector">
          <HeaderIcon />
        </div>
      </li>
    {{/if}}
  </template>
}
