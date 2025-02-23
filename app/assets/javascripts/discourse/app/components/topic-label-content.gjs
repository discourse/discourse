import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import { categoryLinkHTML } from "discourse/helpers/category-link";
import icon from "discourse/helpers/d-icon";
import discourseTags from "discourse/helpers/discourse-tags";

const TopicLabelButton = <template>
  <DButton class={{@class}} @action={{@action}}>
    <div class="topic-title">
      <div class="topic-title__top-line">
        <span class="topic-statuses">
          {{#if (eq @topic.archetype "private_message")}}
            <span class="topic-status">
              {{icon "envelope"}}
            </span>
          {{/if}}

          {{#if @topic.bookmarked}}
            <span class="topic-status">
              {{icon "bookmark"}}
            </span>
          {{/if}}

          {{#if @topic.closed}}
            <span class="topic-status">
              {{icon "lock"}}
            </span>
          {{/if}}

          {{#if @topic.pinned}}
            <span class="topic-status">
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

export default class TopicLabelContent extends Component {
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
