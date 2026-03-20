import { hash } from "@ember/helper";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import SubTitle from "./sub-title";

const ChatNavbarTitle = <template>
  <div
    title={{@title}}
    class={{dConcatClass "c-navbar__title" (if @showFullTitle "full-title")}}
    ...attributes
  >
    <span class="c-navbar__title-text">
      {{if @icon (dIcon @icon)}}
      {{@title}}
    </span>

    {{#if (has-block)}}
      {{yield (hash SubTitle=SubTitle)}}
    {{/if}}
  </div>
</template>;

export default ChatNavbarTitle;
