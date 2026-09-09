import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import {
  SCROLLER_HEIGHT,
  timelineDate,
} from "discourse/components/topic-timeline/container";
import { and, not } from "discourse/truth-helpers";
import dPointerDrag from "discourse/ui-kit/modifiers/d-pointer-drag";
import { i18n } from "discourse-i18n";
import BackButton from "./back-button";

export default class TopicTimelineScroller extends Component {
  style = trustHTML(`height: ${SCROLLER_HEIGHT}px`);

  get repliesShort() {
    return i18n(`topic.timeline.replies_short`, {
      current: this.args.current,
      total: this.args.total,
    });
  }

  get timelineAgo() {
    return timelineDate(this.args.date);
  }

  <template>
    <div
      class="timeline-scroller"
      style={{this.style}}
      ...attributes
      {{! Position is committed continuously as the pointer moves, so discarding
          on cancel would snap the topic back to where the drag began. }}
      {{dPointerDrag
        onDragStart=@didStartDrag
        onDrag=@dragMove
        onDragEnd=@didEndDrag
        cancelCommits=true
        bodyClass="dragging"
      }}
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
