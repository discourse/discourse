import { hash } from "@ember/helper";
import PluginOutlet from "discourse/components/plugin-outlet";
import PostActionsSummary from "./actions-summary";
import PostContents from "./contents";
import PostLinks from "./links";
import PostMetaData from "./meta-data";

const PostBody = <template>
  <div class="topic-body clearfix">
    <PluginOutlet @name="post-metadata" @outletArgs={{hash post=@post}}>
      <PostMetaData
        @post={{@post}}
        @editPost={{@editPost}}
        @multiSelect={{@multiSelect}}
        @repliesAbove={{@repliesAbove}}
        @selectBelow={{@selectBelow}}
        @selectReplies={{@selectReplies}}
        @selected={{@selected}}
        @showHistory={{@showHistory}}
        @showRawEmail={{@showRawEmail}}
        @togglePostSelection={{@togglePostSelection}}
        @toggleReplyAbove={{@toggleReplyAbove}}
      />
    </PluginOutlet>
    <PostContents
      @post={{@post}}
      @prevPost={{@prevPost}}
      @nextPost={{@nextPost}}
      @canCreatePost={{@canCreatePost}}
      @changeNotice={{@changeNotice}}
      @changePostOwner={{@changePostOwner}}
      @deletePost={{@deletePost}}
      @editPost={{@editPost}}
      @grantBadge={{@grantBadge}}
      @lockPost={{@lockPost}}
      @permanentlyDeletePost={{@permanentlyDeletePost}}
      @rebakePost={{@rebakePost}}
      @recoverPost={{@recoverPost}}
      @replyToPost={{@replyToPost}}
      @showFlags={{@showFlags}}
      @showLogin={{@showLogin}}
      @showPagePublish={{@showPagePublish}}
      @showReadIndicator={{@showReadIndicator}}
      @toggleLike={{@toggleLike}}
      @togglePostType={{@togglePostType}}
      @toggleReplies={{@toggleReplies}}
      @toggleWiki={{@toggleWiki}}
      @unhidePost={{@unhidePost}}
      @unlockPost={{@unlockPost}}
    />
    <section class="post-actions">
      <PostActionsSummary @post={{@post}} />
    </section>
    <PostLinks @post={{@post}} />
  </div>
</template>;

export default PostBody;
