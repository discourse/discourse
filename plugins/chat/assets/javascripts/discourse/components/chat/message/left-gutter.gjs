import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import BookmarkIcon from "discourse/components/bookmark-icon";
import dIcon from "discourse/helpers/d-icon";
import formatChatDate from "../../../helpers/format-chat-date";

export default class ChatMessageLeftGutter extends Component {
  @service site;

  <template>
    <div class="chat-message-left-gutter">
      {{#if @message.reviewableId}}
        <LinkTo
          @route="review.show"
          @model={{@message.reviewableId}}
          class="chat-message-left-gutter__flag"
        >
          {{dIcon "flag" title="chat.flagged"}}
        </LinkTo>
      {{else if (eq @message.userFlagStatus 0)}}
        <div class="chat-message-left-gutter__flag">
          {{dIcon "flag" title="chat.you_flagged"}}
        </div>
      {{else if this.site.desktopView}}
        <span class="chat-message-left-gutter__date">
          {{formatChatDate
            @message
            (hash mode="tiny" threadContext=@threadContext)
          }}
        </span>
      {{/if}}
      {{#if @message.bookmark}}
        <span class="chat-message-left-gutter__bookmark">
          <BookmarkIcon @bookmark={{@message.bookmark}} />
        </span>
      {{/if}}
    </div>
  </template>
}
