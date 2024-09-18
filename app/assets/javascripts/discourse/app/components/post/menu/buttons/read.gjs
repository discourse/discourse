import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";
import i18n from "discourse-common/helpers/i18n";

export default class PostMenuReadButton extends Component {
  static shouldRender(args) {
    return args.context.showReadIndicator && args.post.readers_count > 0;
  }

  <template>
    {{#if @shouldRender}}
      <div class="double-button">
        <DButton
          class="button-count read-indicator"
          ...attributes
          @ariaPressed={{@context.isWhoReadVisible}}
          @action={{@buttonActions.toggleWhoRead}}
          @translatedAriaLabel={{i18n
            "post.sr_post_read_count_button"
            count=@post.readers_count
          }}
          @title="post.controls.read_indicator"
        >
          {{@post.readers_count}}
        </DButton>
        <DButton
          ...attributes
          @action={{@buttonActions.toggleWhoRead}}
          @icon="book-reader"
          @title="post.controls.read_indicator"
        />
      </div>
    {{/if}}
  </template>
}
