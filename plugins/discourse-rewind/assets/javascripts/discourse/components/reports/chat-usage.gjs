import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import avatar from "discourse/helpers/avatar";
import number from "discourse/helpers/number";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

const BotMessage = <template>
  <div class="chat-message__avatar">🤖</div>
  <div class="chat-message__bubble">
    <div class="chat-message__author">
      {{i18n "discourse_rewind.reports.chat_usage.bot_name"}}
    </div>
    {{#if @message}}
      <div class="chat-message__text">
        {{htmlSafe @message}}
      </div>
    {{/if}}
    {{yield}}
  </div>
</template>;

const UserMessage = <template>
  <div class="chat-message__bubble">
    <div class="chat-message__author">
      {{i18n "discourse_rewind.reports.chat_usage.you"}}
    </div>
    {{#if @replyKey}}
      <div class="chat-message__text">
        {{i18n (concat "discourse_rewind.reports.chat_usage." @replyKey)}}
      </div>
    {{/if}}
    {{yield}}
  </div>
  <div class="chat-message__avatar">
    {{avatar @user imageSize="small"}}
  </div>
</template>;

export default class ChatUsage extends Component {
  get favoriteChannels() {
    return this.args.report.data.favorite_channels ?? [];
  }

  get minimumDataThresholdMet() {
    return (
      this.args.report.data.total_messages >= 20 &&
      this.args.report.data.unique_dm_channels >= 2 &&
      this.args.report.data.favorite_channels.length >= 1
    );
  }

  <template>
    {{#if this.minimumDataThresholdMet}}
      <div class="rewind-report-page --chat-usage">
        <h2 class="rewind-report-title">{{i18n
            "discourse_rewind.reports.chat_usage.title"
          }}</h2>

        <div class="chat-window">
          <div class="chat-window__header">
            <span class="chat-window__title">
              {{i18n "discourse_rewind.reports.chat_usage.channel_title"}}
            </span>
            <span class="chat-window__status">
              {{i18n "discourse_rewind.reports.chat_usage.status_online"}}
            </span>
          </div>

          <div class="chat-window__messages">
            <div class="chat-message --left">
              <BotMessage
                @message={{i18n
                  "discourse_rewind.reports.chat_usage.message_1"
                  count=(number @report.data.total_messages)
                }}
              />
            </div>

            <div class="chat-message --right">
              <UserMessage @user={{@user}} @replyKey="reply_1" />
            </div>

            <div class="chat-message --left">
              <BotMessage
                @message={{htmlSafe
                  (i18n
                    "discourse_rewind.reports.chat_usage.message_2"
                    dm_count=(number @report.data.dm_message_count)
                    channel_count=(number @report.data.unique_dm_channels)
                  )
                }}
              />
            </div>

            <div class="chat-message --right">
              <UserMessage @user={{@user}} @replyKey="reply_2" />
            </div>

            <div class="chat-message --left">
              <BotMessage
                @message={{htmlSafe
                  (i18n
                    "discourse_rewind.reports.chat_usage.message_3"
                    count=(number @report.data.total_reactions_received)
                  )
                }}
              />
            </div>

            <div class="chat-message --right">
              <UserMessage @user={{@user}} @replyKey="reply_3" />
            </div>

            <div class="chat-message --left">
              <BotMessage
                @message={{htmlSafe
                  (i18n
                    "discourse_rewind.reports.chat_usage.message_4"
                    length=@report.data.avg_message_length
                  )
                }}
              />
            </div>

            {{#if this.favoriteChannels.length}}
              <div class="chat-message --left">
                <BotMessage
                  @message={{i18n
                    "discourse_rewind.reports.chat_usage.message_5"
                  }}
                >
                  <div class="chat-message__channels">
                    {{#each this.favoriteChannels as |channel|}}
                      <a
                        class="chat-channel-link"
                        href={{getURL (concat "/chat/c/-/" channel.channel_id)}}
                      >
                        <span
                          class="chat-channel-link__name"
                        >#{{channel.channel_slug}}</span>
                        <span class="chat-channel-link__count">
                          {{number channel.message_count}}
                        </span>
                      </a>
                    {{/each}}
                  </div>
                </BotMessage>
              </div>
            {{/if}}

            <div class="chat-message --right">
              <UserMessage @user={{@user}}>
                <img
                  src={{getURL
                    "/plugins/discourse-rewind/images/dancing_baby.gif"
                  }}
                  alt={{i18n
                    "discourse_rewind.reports.chat_usage.dancing_baby_alt"
                  }}
                  class="chat-message__gif"
                />
              </UserMessage>
            </div>
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
