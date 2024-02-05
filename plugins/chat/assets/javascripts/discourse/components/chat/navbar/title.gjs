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
      <span class="c-navbar__title-text">{{if @icon (icon @icon)}}
        {{@title}}</span>
      {{yield (hash SubTitle=SubTitle)}}
    {{else}}
      <span class="c-navbar__title-text">{{if
          @icon
          (icon @icon)
        }}{{@title}}</span>
    {{/if}}
  </div>
</template>;

export default ChatNavbarTitle;
