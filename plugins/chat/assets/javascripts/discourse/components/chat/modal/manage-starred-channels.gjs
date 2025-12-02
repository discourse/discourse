import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DModalCancel from "discourse/components/d-modal-cancel";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import ChannelIcon from "discourse/plugins/chat/discourse/components/channel-icon";

export default class ChatModalManageStarredChannels extends Component {
  @service chatApi;
  @service chatChannelsManager;

  @tracked togglingChannelIds = new Set();

  get allFollowingChannels() {
    const publicChannels = this.chatChannelsManager.publicMessageChannels;
    const dmChannels = this.chatChannelsManager.directMessageChannels;
    return [...publicChannels, ...dmChannels];
  }

  @action
  async toggleStarred(channel, event) {
    event?.preventDefault();
    event?.stopPropagation();

    if (this.togglingChannelIds.has(channel.id)) {
      return;
    }

    this.togglingChannelIds.add(channel.id);

    try {
      const newStarredValue = !channel.currentUserMembership.starred;

      await this.chatApi.updateCurrentUserChannelMembership(channel.id, {
        starred: newStarredValue,
      });

      channel.currentUserMembership.starred = newStarredValue;
    } catch {
      // Error is handled by chatApi
    } finally {
      this.togglingChannelIds.delete(channel.id);
    }
  }

  @action
  getChannelTitle(channel) {
    if (channel.isDirectMessageChannel) {
      return channel.title;
    }
    return htmlSafe(emojiUnescape(escapeExpression(channel.title)));
  }

  @action
  isToggling(channelId) {
    return this.togglingChannelIds.has(channelId);
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n "chat.manage_starred_channels.title"}}
      class="chat-modal-manage-starred-channels"
    >
      <:body>
        <div class="manage-starred-channels">
          <div class="manage-starred-channels__list">
            {{#if this.allFollowingChannels.length}}
              {{#each this.allFollowingChannels as |channel|}}
                <div class="manage-starred-channels__row">
                  <div class="manage-starred-channels__channel-info">
                    <ChannelIcon @channel={{channel}} />
                    <span class="manage-starred-channels__channel-title">
                      {{this.getChannelTitle channel}}
                    </span>
                  </div>
                  <DButton
                    @action={{fn this.toggleStarred channel}}
                    @icon={{if
                      channel.currentUserMembership.starred
                      "star"
                      "far-star"
                    }}
                    @title={{if
                      channel.currentUserMembership.starred
                      (i18n "chat.manage_starred_channels.unstar")
                      (i18n "chat.manage_starred_channels.star")
                    }}
                    class={{if
                      channel.currentUserMembership.starred
                      "btn-transparent manage-starred-channels__star-button --starred"
                      "btn-transparent manage-starred-channels__star-button"
                    }}
                    @disabled={{this.isToggling channel.id}}
                  />
                </div>
              {{/each}}
            {{else}}
              <div class="manage-starred-channels__empty">
                {{i18n "chat.manage_starred_channels.no_channels"}}
              </div>
            {{/if}}
          </div>
        </div>
      </:body>

      <:footer>
        <DModalCancel @close={{@closeModal}} />
      </:footer>
    </DModal>
  </template>
}
