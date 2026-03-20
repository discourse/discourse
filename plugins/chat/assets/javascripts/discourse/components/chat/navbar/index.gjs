import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import noop from "discourse/helpers/noop";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dOnResize from "discourse/ui-kit/modifiers/d-on-resize";
import Actions from "./actions";
import BackButton from "./back-button";
import ChannelTitle from "./channel-title";
import Title from "./title";

export default class ChatNavbar extends Component {
  @action
  handleResize(entries) {
    for (let entry of entries) {
      const height = entry.target.clientHeight;

      requestAnimationFrame(() => {
        document.documentElement.style.setProperty(
          "--chat-header-expanded-offset",
          `${height}px`
        );
      });
    }
  }

  <template>
    {{! template-lint-disable no-invalid-interactive }}
    <div
      class={{dConcatClass "c-navbar-container" (if @onClick "-clickable")}}
      {{on "click" (if @onClick @onClick (noop))}}
      {{dOnResize this.handleResize}}
    >
      <nav class="c-navbar">
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
