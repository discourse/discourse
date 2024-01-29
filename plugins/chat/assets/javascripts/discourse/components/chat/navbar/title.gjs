import { hash } from "@ember/helper";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse-common/helpers/d-icon";
import SubTitle from "./sub-title";

const ChatNavbarTitle = <template>
  <div
    title={{@title}}
    class={{concatClass "c-navbar__title" (if @showFullTitle "full-title")}}
  >
    {{#if (has-block)}}
      {{if @icon (icon @icon)}}
      {{@title}}
      {{yield (hash SubTitle=SubTitle)}}
    {{else}}
      {{if @icon (icon @icon)}}
      {{@title}}
    {{/if}}
  </div>
</template>;

export default ChatNavbarTitle;
