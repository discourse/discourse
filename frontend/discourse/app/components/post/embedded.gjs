import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import PostAvatar from "./avatar";
import PostCookedHtml from "./cooked-html";
import PostMetaDataPosterName from "./meta-data/poster-name";

const PostEmbedded = <template>
  <div ...attributes class="reply" data-post-id={{@post.id}}>
    <div class="row">
      <PostAvatar @post={{@post}} />
      <div class="topic-body">
        <div class="topic-meta-data embedded-reply">
          <PostMetaDataPosterName @post={{@post}} />
          <div class="post-link-arrow">
            <a
              aria-label={{i18n
                "topic.jump_reply_aria"
                username=@post.username
              }}
              class="post-info arrow"
              href={{@post.shareUrl}}
              title={{i18n "topic.jump_reply"}}
            >
              {{#if @above}}
                {{dIcon "arrow-up"}}
              {{else}}
                {{dIcon "arrow-down"}}
              {{/if}}
              {{i18n "topic.jump_reply_button"}}
            </a>
          </div>
        </div>
        <PostCookedHtml
          @highlightTerm={{@highlightTerm}}
          @post={{@post}}
          @streamElement={{@streamElement}}
        />
      </div>
    </div>
  </div>
</template>;

export default PostEmbedded;
