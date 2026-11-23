import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import getURL from "discourse/lib/get-url";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dNumber from "discourse/ui-kit/helpers/d-number";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import I18n, { i18n } from "discourse-i18n";
import RewindWindow from "discourse/plugins/discourse-rewind/discourse/components/rewind-window";
import { i18nForOwner } from "discourse/plugins/discourse-rewind/discourse/lib/rewind-i18n";

const BotMessage = <template>
  <li class="rewind-chat__message --bot">
    <span aria-hidden="true" class="rewind-chat__who"></span>
    <div class="rewind-balloon">
      <p class="rewind-chat__author">{{i18n
          "discourse_rewind.reports.chat_usage.bot_name"
        }}</p>
      {{#if @message}}{{dReplaceEmoji (trustHTML @message)}}{{/if}}
      {{yield}}
    </div>
  </li>
</template>;

const UserMessage = <template>
  <li class="rewind-chat__message --user">
    <span class="rewind-chat__who">
      {{dAvatar @user imageSize="medium" extraClasses="rewind-avatar"}}
    </span>
    <div class="rewind-balloon --inverse">
      <p class="rewind-chat__author">{{@author}}</p>
      {{@text}}
    </div>
  </li>
</template>;

export default class ChatUsage extends Component {
  @service currentUser;

  get authorText() {
    return i18nForOwner(
      "discourse_rewind.reports.chat_usage.author",
      this.args.isOwnRewind,
      { username: this.args.user?.username }
    );
  }

  get avatarUser() {
    return this.args.isOwnRewind && this.currentUser
      ? this.currentUser
      : this.args.user;
  }

  get message1Text() {
    return i18n("discourse_rewind.reports.chat_usage.message_1", {
      count: this.args.report.data.total_messages,
    });
  }

  get message2Text() {
    return I18n.messageFormat(
      "discourse_rewind.reports.chat_usage.message_2_MF",
      {
        dm_count: this.args.report.data.dm_message_count,
        channel_count: this.args.report.data.unique_dm_channels,
      }
    );
  }

  get message3Text() {
    return i18n("discourse_rewind.reports.chat_usage.message_3", {
      count: this.args.report.data.total_reactions_received,
    });
  }

  get message4Text() {
    return i18n("discourse_rewind.reports.chat_usage.message_4", {
      length: this.args.report.data.avg_message_length,
    });
  }

  <template>
    <div class="rewind-report-page --chat-usage">
      <h2 class="rewind-report-title">{{i18n
          "discourse_rewind.reports.chat_usage.title"
        }}</h2>
      <RewindWindow
        class="rewind-chat"
        @title={{i18n "discourse_rewind.reports.chat_usage.channel_title"}}
      >
        <p class="rewind-chat__status">{{i18n
            "discourse_rewind.reports.chat_usage.status_online"
          }}</p>
        <ol class="rewind-chat__thread">
          <BotMessage @message={{this.message1Text}} />
          <UserMessage
            @author={{this.authorText}}
            @text={{i18n "discourse_rewind.reports.chat_usage.reply_1"}}
            @user={{this.avatarUser}}
          />
          <BotMessage @message={{this.message2Text}} />
          <UserMessage
            @author={{this.authorText}}
            @text={{i18n "discourse_rewind.reports.chat_usage.reply_2"}}
            @user={{this.avatarUser}}
          />
          <BotMessage @message={{this.message3Text}} />
          <UserMessage
            @author={{this.authorText}}
            @text={{i18n "discourse_rewind.reports.chat_usage.reply_3"}}
            @user={{this.avatarUser}}
          />
          <BotMessage @message={{this.message4Text}} />
          {{#if @report.data.favorite_channels.length}}
            <BotMessage
              @message={{i18n "discourse_rewind.reports.chat_usage.message_5"}}
            >
              <ol class="rewind-chat__channels">
                {{#each @report.data.favorite_channels as |channel|}}
                  <li>
                    <a
                      class="rewind-chat__channel"
                      href={{getURL (concat "/chat/c/-/" channel.channel_id)}}
                    >
                      <span>#{{channel.channel_slug}}</span>
                      <span>{{dNumber channel.message_count}}</span>
                    </a>
                  </li>
                {{/each}}
              </ol>
            </BotMessage>
          {{/if}}
        </ol>
      </RewindWindow>
    </div>
  </template>
}
