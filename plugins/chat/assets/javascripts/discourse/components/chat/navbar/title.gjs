import { hash } from "@ember/helper";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse-common/helpers/d-icon";
import SubTitle from "./sub-title";

const ChatNavbarTitle = <template>
  <div
    title={{@title}}
    class={{concatClass "c-navbar__title" (if @showFullTitle "full-title")}}
  >
    {{#if @openThreadTitleModal}}
      <DButton
        class="c-navbar__title-text btn-transparent"
        @icon={{@icon}}
        @action={{@openThreadTitleModal}}
        @translatedLabel={{@title}}
      />
    {{else}}
      <span class="c-navbar__title-text">
        {{if @icon (icon @icon)}}
        {{@title}}
      </span>
    {{/if}}
    {{#if (has-block)}}
      {{yield (hash SubTitle=SubTitle)}}
    {{/if}}
  </div>
</template>;

export default ChatNavbarTitle;
