import Component from "@glimmer/component";
import { or } from "truth-helpers";
import PostEditsIndicator from "./meta-data/edits-indicator";
import PostEmailMetaDataIndicator from "./meta-data/email-indicator";
import PostLockedIndicator from "./meta-data/locked-indicator";
import PostWhisperMetaDataIndicator from "./meta-data/whisper-indicator";

export default class PostMetaData extends Component {
  get displayPosterName() {
    return this.args.displayPosterName ?? true;
  }

  <template>
    <div class="topic-meta-data" role="heading" aria-level="2">
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
    </div>
  </template>
}
