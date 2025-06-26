import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import DAG from "discourse/lib/dag";
import { applyMutableValueTransformer } from "discourse/lib/transformer";
import PostMetaDataDate from "./meta-data/date";
import PostMetaDataEditsIndicator from "./meta-data/edits-indicator";
import PostMetaDataEmailIndicator from "./meta-data/email-indicator";
import PostMetaDataLanguage from "./meta-data/language";
import PostMetaDataLockedIndicator from "./meta-data/locked-indicator";
import PostMetaDataPosterName from "./meta-data/poster-name";
import PostMetaDataReadIndicator from "./meta-data/read-indicator";
import PostMetaDataReplyToTab from "./meta-data/reply-to-tab";
import PostMetaDataSelectPost from "./meta-data/select-post";
import PostMetaDataWhisperIndicator from "./meta-data/whisper-indicator";

const metaDataInfoKeys = Object.freeze({
  WHISPER_INDICATOR: "whisper_indicator",
  EMAIL_INDICATOR: "email_indicator",
  LOCKED_INDICATOR: "locked_indicator",
  EDITS_INDICATOR: "edits_indicator",
  SELECT_POST: "select_post",
  REPLY_TO_TAB: "reply_to_tab",
  LANGUAGE: "language",
  DATE: "date",
  READ_INDICATOR: "read_indicator",
});

const INFO_DEFINITIONS = {
  [metaDataInfoKeys.WHISPER_INDICATOR]: {
    Component: PostMetaDataWhisperIndicator,
    shouldRender: (args) => args.post.isWhisper,
  },
  [metaDataInfoKeys.EMAIL_INDICATOR]: {
    Component: PostMetaDataEmailIndicator,
    shouldRender: (args) => args.post.via_email,
  },
  [metaDataInfoKeys.LOCKED_INDICATOR]: {
    Component: PostMetaDataLockedIndicator,
    shouldRender: (args) => args.post.locked,
  },
  [metaDataInfoKeys.EDITS_INDICATOR]: {
    Component: PostMetaDataEditsIndicator,
    shouldRender: (args) => args.post.version > 1 || args.post.wiki,
  },
  [metaDataInfoKeys.SELECT_POST]: {
    Component: PostMetaDataSelectPost,
    shouldRender: (args) => args.multiSelect,
  },
  [metaDataInfoKeys.REPLY_TO_TAB]: {
    Component: PostMetaDataReplyToTab,
    shouldRender: (args, owner) =>
      PostMetaDataReplyToTab.shouldRender(args, null, owner),
  },
  [metaDataInfoKeys.LANGUAGE]: {
    Component: PostMetaDataLanguage,
    shouldRender: (args) => args.post.is_localized && args.post.language,
  },
  [metaDataInfoKeys.DATE]: {
    Component: PostMetaDataDate,
    shouldRender: () => true,
  },
  [metaDataInfoKeys.READ_INDICATOR]: {
    Component: PostMetaDataReadIndicator,
    shouldRender: () => true,
  },
};

const INFO_COMPONENTS = Array.from(Object.entries(INFO_DEFINITIONS)).map(
  ([key, { Component: InfoComponent }]) => [key, InfoComponent]
);

export default class PostMetaData extends Component {
  @cached
  get availableInfoComponents() {
    return this.#infoComponentsDag
      .resolve()
      .filter(({ key }) => {
        const shouldRender = INFO_DEFINITIONS[key]?.shouldRender;
        return shouldRender ? shouldRender(this.args, getOwner(this)) : true;
      })
      .map(({ key, value: InfoComponent }) => ({ key, InfoComponent }));
  }

  get shouldDisplayPosterName() {
    return this.args.displayPosterName ?? true;
  }

  // The metadata components are managed in a Directed Acyclic Graph (DAG)
  // to allow plugins to modify the list (e.g., add new items or reorder).
  get #infoComponentsDag() {
    return applyMutableValueTransformer(
      "post-meta-data-infos",
      DAG.from(INFO_COMPONENTS, {
        throwErrorOnCycle: false,
      }),
      { post: this.args.post, metaDataInfoKeys }
    );
  }

  <template>
    <div class="topic-meta-data" role="heading" aria-level="2">
      {{#if this.shouldDisplayPosterName}}
        <PostMetaDataPosterName @post={{@post}} />
      {{/if}}

      <div class="post-infos">
        {{! do not include PluginOutlets here, use the DAG API instead }}
        {{#each this.availableInfoComponents key="key" as |item|}}
          <item.InfoComponent
            @post={{@post}}
            @editPost={{@editPost}}
            @hasRepliesAbove={{@hasRepliesAbove}}
            @isReplyingDirectlyToPostAbove={{@isReplyingDirectlyToPostAbove}}
            @repliesAbove={{@repliesAbove}}
            @selectBelow={{@selectBelow}}
            @selectReplies={{@selectReplies}}
            @selected={{@selected}}
            @showHistory={{@showHistory}}
            @showRawEmail={{@showRawEmail}}
            @togglePostSelection={{@togglePostSelection}}
            @toggleReplyAbove={{@toggleReplyAbove}}
          />
        {{/each}}
      </div>
    </div>
  </template>
}
