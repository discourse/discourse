import { and, gt } from "truth-helpers";
import DButton from "discourse/components/d-button";
import i18n from "discourse-common/helpers/i18n";

const PostMenuReadButton = <template>
  {{#if
    (and @transformedPost.showReadIndicator (gt @transformedPost.readCount 0))
  }}
    <div class="double-button">
      <DButton
        class="button-count read-indicator"
        ...attributes
        @ariaPressed={{gt @state.readers.length 0}}
        @action={{@action}}
        @translatedAriaLabel={{i18n
          "post.sr_post_read_count_button"
          count=@transformedPost.readCount
        }}
        @title="post.controls.read_indicator"
      >
        {{@transformedPost.readCount}}
      </DButton>
      <DButton
        ...attributes
        @action={{@action}}
        @icon="book-reader"
        @title="post.controls.read_indicator"
      />
    </div>
  {{/if}}
</template>;

export default PostMenuReadButton;
