import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import { categoryLinkHTML } from "discourse/helpers/category-link";
import icon from "discourse/helpers/d-icon";
import discourseTags from "discourse/helpers/discourse-tags";
import { eq } from "discourse/truth-helpers";

const TopicLabelButton = <template>
  <DButton class={{@class}} @action={{@action}}>
    <div class="topic-title">
      <div class="topic-title__top-line">
        <span class="topic-statuses">
          {{#if (eq @topic.archetype "private_message")}}
            <span class="topic-status --private-message">
              {{icon "envelope"}}
            </span>
          {{/if}}

          {{#if @topic.bookmarked}}
            <span class="topic-status --bookmarked">
              {{icon "bookmark"}}
            </span>
          {{/if}}

          {{#if @topic.closed}}
            <span class="topic-status --closed">
              {{icon "topic.closed"}}
            </span>
          {{/if}}

          {{#if @topic.pinned}}
            <span class="topic-status --pinned">
              {{icon "thumbtack"}}
            </span>
          {{/if}}

        </span>
        <span class="fancy-title">
          {{@topic.title}}
        </span>
      </div>
      <div class="topic-title__bottom-line">
        {{categoryLinkHTML @topic.category (hash link=false)}}
        {{discourseTags @topic}}
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
      @class="btn-primary btn-reply-where btn-reply-on-original"
      @action={{this.replyOnOriginal}}
      @topic={{@model.originalTopic}}
    />

    <TopicLabelButton
      @class="btn-reply-where btn-reply-here"
      @action={{this.replyOnCurrent}}
      @topic={{@model.currentTopic}}
    />
  </template>
}
