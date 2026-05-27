import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { categoryLinkHTML } from "discourse/ui-kit/helpers/d-category-link";
import dDiscourseTags from "discourse/ui-kit/helpers/d-discourse-tags";
import dIcon from "discourse/ui-kit/helpers/d-icon";

const TopicLabelButton = <template>
  <DButton @action={{@action}} ...attributes>
    <div class="topic-title">
      <div class="topic-title__top-line">
        <span class="topic-statuses">
          {{#if (eq @topic.archetype "private_message")}}
            <span class="topic-status --private-message">
              {{dIcon "envelope"}}
            </span>
          {{/if}}

          {{#if @topic.bookmarked}}
            <span class="topic-status --bookmarked">
              {{dIcon "bookmark"}}
            </span>
          {{/if}}

          {{#if @topic.closed}}
            <span class="topic-status --closed">
              {{dIcon "topic.closed"}}
            </span>
          {{/if}}

          {{#if @topic.pinned}}
            <span class="topic-status --pinned">
              {{dIcon "thumbtack"}}
            </span>
          {{/if}}

        </span>
        <span class="fancy-title">
          {{@topic.title}}
        </span>
      </div>
      <div class="topic-title__bottom-line">
        {{categoryLinkHTML @topic.category (hash link=false)}}
        {{dDiscourseTags @topic}}
      </div>
    </div>
  </DButton>
</template>;

export default class TopicReplyChoiceDialog extends Component {
  @action
  replyOnOriginal() {
    this.args.model.replyOnOriginal();
  }

  @action
  replyOnCurrent() {
    this.args.model.replyOnCurrent();
  }

  <template>
    <TopicLabelButton
      @action={{this.replyOnOriginal}}
      @topic={{@model.originalTopic}}
      class="btn-primary btn-reply-where btn-reply-on-original"
    />

    <TopicLabelButton
      @action={{this.replyOnCurrent}}
      @topic={{@model.currentTopic}}
      class="btn-reply-where btn-reply-here"
    />
  </template>
}
