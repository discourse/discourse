import { trustHTML } from "@ember/template";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";

const Post = <template>
  {{#if @ctx.post}}
    <aside
      class="quote"
      data-post={{@ctx.post.post_number}}
      data-topic={{@ctx.post.topic_id}}
    >
      <div class="title">
        <div class="quote-controls">
          {{! template-lint-disable no-invalid-link-text }}
          <a
            href="/t/via-quote/{{@ctx.post.topic_id}}/{{@ctx.post.post_number}}"
            title="go to the quoted post"
            class="quote-other-topic"
          >
          </a>
        </div>

        <a
          class="result-post-link"
          href="/t/{{@ctx.post.topic_id}}/{{@ctx.post.post_number}}"
        >
          {{dAvatar @ctx.post imageSize="tiny"}}{{@ctx.post.username}}:
        </a>
      </div>

      <blockquote>
        <p>
          {{trustHTML @ctx.post.excerpt}}
        </p>
      </blockquote>
    </aside>
  {{else}}
    {{@ctx.id}}
  {{/if}}
</template>;

export default Post;
