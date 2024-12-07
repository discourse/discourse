import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

export default class PostMenuReadButton extends Component {
  static shouldRender(args) {
    return args.state.showReadIndicator && args.post.readers_count > 0;
  }

  <template>
    <div class="double-button">
      <DButton
        class="post-action-menu__read read-indicator button-count"
        ...attributes
        @ariaPressed={{@state.isWhoReadVisible}}
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
        @icon="book-open-reader"
        @title="post.controls.read_indicator"
      />
    </div>
  </template>
}
