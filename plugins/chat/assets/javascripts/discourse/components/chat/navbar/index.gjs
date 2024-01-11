import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import concatClass from "discourse/helpers/concat-class";
import noop from "discourse/helpers/noop";
import Actions from "./actions";
import BackButton from "./back-button";
import ChannelTitle from "./channel-title";
import Title from "./title";

const ChatNavbar = <template>
  {{! template-lint-disable no-invalid-interactive }}
  <div
    class={{concatClass "c-navbar-container" (if @onClick "-clickable")}}
    {{on "click" (if @onClick @onClick (noop))}}
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
</template>;

export default ChatNavbar;
