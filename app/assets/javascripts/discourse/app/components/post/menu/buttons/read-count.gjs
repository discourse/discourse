import Component from "@glimmer/component";
import { gt } from "truth-helpers";
import DButton from "discourse/components/d-button";
import i18n from "discourse-common/helpers/i18n";

export default class PostMenuReadCountButton extends Component {
  get shouldRender() {
    return this.args.post.showReadIndicator && this.args.post.readCount > 0;
  }

  <template>
    {{#if this.shouldRender}}
      <DButton
        class="button-count read-indicator"
        aria-pressed={{if (gt @state.readers.length 0) "true" "false"}}
        @action={{@action}}
        @translatedAriaLabel={{i18n
          "post.sr_post_read_count_button"
          count=@readCount
        }}
        @title="post.controls.read_indicator"
      >
        {{@post.readCount}}
      </DButton>
    {{/if}}
  </template>
}
