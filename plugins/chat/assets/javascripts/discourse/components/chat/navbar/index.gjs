import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import concatClass from "discourse/helpers/concat-class";
import noop from "discourse/helpers/noop";
import ChatOnResize from "../../../modifiers/chat/on-resize";
import Actions from "./actions";
import BackButton from "./back-button";
import ChannelTitle from "./channel-title";
import Title from "./title";

export default class ChatNavbar extends Component {
  @action
  handleResize(entries) {
    for (let entry of entries) {
      const height = entry.target.clientHeight;
      document.documentElement.style.setProperty(
        "--chat-thread-header-offset",
        `${height}px`
      );
    }
  }

  <template>
    {{! template-lint-disable no-invalid-interactive }}
    <div
      class={{concatClass "c-navbar-container" (if @onClick "-clickable")}}
      {{on "click" (if @onClick @onClick (noop))}}
    >
      <nav
        class={{concatClass "c-navbar" (if @showFullTitle "-full-title")}}
        {{ChatOnResize this.handleResize}}
      >
        {{yield
          (hash
            BackButton=BackButton
            ChannelTitle=ChannelTitle
            Title=Title
            Actions=Actions
          )
        }}
      </nav>
    </div>
  </template>
}
