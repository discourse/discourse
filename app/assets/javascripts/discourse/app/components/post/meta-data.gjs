import Component from "@glimmer/component";
import { and, not, or } from "truth-helpers";
import PostEditsIndicator from "./meta-data/edits-indicator";
import PostEmailMetaDataIndicator from "./meta-data/email-indicator";
import PostLockedIndicator from "./meta-data/locked-indicator";
import PostMetaDataReplyToTab from "./meta-data/reply-to-tab";
import PostMetaDataSelectPost from "./meta-data/select-post";
import PostWhisperMetaDataIndicator from "./meta-data/whisper-indicator";

export default class PostMetaData extends Component {
  get displayPosterName() {
    return this.args.displayPosterName ?? true;
  }

  <template>
    <div class="topic-meta-data" role="heading" aria-level="2">
      {{#if this.displayPosterName}}
        <PostMetaDataPosterName @post={{@post}} />
      {{/if}}

      <div class="post-infos">
        {{#if @post.isWhisper}}
          <PostWhisperMetaDataIndicator @post={{@post}} />
        {{/if}}

        {{#if @post.via_email}}
          <PostEmailMetaDataIndicator
            @post={{@post}}
            @showRawEmail={{@showRawEmail}}
          />
        {{/if}}

        {{#if @post.locked}}
          <PostLockedIndicator @post={{@post}} />
        {{/if}}

        {{#if (or @post.version @post.wiki)}}
          <PostEditsIndicator
            @post={{@post}}
            @editPost={{@editPost}}
            @showHistory={{@showHistory}}
          />
        {{/if}}

        {{#if @multiSelect}}
          <PostMetaDataSelectPost
            @post={{@post}}
            @selected={{@selected}}
            @selectReplies={{@selectReplies}}
            @selectBelow={{@selectBelow}}
            @togglePostSelection={{@togglePostSelection}}
          />
        {{/if}}

        {{#if
          (and
            @post.replyToUsername
            (or
              (not @post.replyDirectlyAbove)
              (not this.siteSettings.suppress_reply_directly_above)
            )
          )
        }}
          <PostMetaDataReplyToTab
            @post={{@post}}
            @repliesAbove={{@repliesAbove}}
            @toggleReplyAbove={{@toggleReplyAbove}}
          />
        {{/if}}

        <PostMetaDataDate @post={{@post}} />
      </div>
    </div>
  </template>
}
