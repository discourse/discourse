import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import { and, not } from "truth-helpers";
import {
  SCROLLER_HEIGHT,
  timelineDate,
} from "discourse/components/topic-timeline/container";
import draggable from "discourse/modifiers/draggable";
import I18n from "discourse-i18n";
import BackButton from "./back-button";

export default class TopicTimelineScroller extends Component {
  style = htmlSafe(`height: ${SCROLLER_HEIGHT}px`);

  get repliesShort() {
    return I18n.t(`topic.timeline.replies_short`, {
      current: this.args.current,
      total: this.args.total,
    });
  }

  get timelineAgo() {
    return timelineDate(this.args.date);
  }

  <template>
    <div
      {{draggable
        didStartDrag=@didStartDrag
        didEndDrag=@didEndDrag
        dragMove=@dragMove
      }}
      style={{this.style}}
      class="timeline-scroller"
      ...attributes
    >
      {{#if @fullscreen}}
        <div class="timeline-scroller-content">
          <div class="timeline-replies">
            {{this.repliesShort}}
          </div>
          {{#if @date}}
            <div class="timeline-ago">
              {{this.timelineAgo}}
            </div>
          {{/if}}
          {{#if (and @showDockedButton (not @dragging))}}
            <BackButton @onGoBack={{@onGoBack}} />
          {{/if}}
        </div>
        <div class="timeline-handle"></div>
      {{else}}
        <div class="timeline-handle"></div>
        <div class="timeline-scroller-content">
          <div class="timeline-replies">
            {{this.repliesShort}}
          </div>
          {{#if @date}}
            <div class="timeline-ago">
              {{this.timelineAgo}}
            </div>
          {{/if}}
          {{#if (and @showDockedButton (not @dragging))}}
            <BackButton @onGoBack={{@onGoBack}} />
          {{/if}}
        </div>
      {{/if}}
    </div>
  </template>
}
