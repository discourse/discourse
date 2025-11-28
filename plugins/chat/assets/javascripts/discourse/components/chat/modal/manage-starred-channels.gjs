import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DModalCancel from "discourse/components/d-modal-cancel";
import FilterInput from "discourse/components/filter-input";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import ChannelIcon from "discourse/plugins/chat/discourse/components/channel-icon";

export default class ChatModalManageStarredChannels extends Component {
  @service chatApi;
  @service chatChannelsManager;

  @tracked filter = "";
  @tracked togglingChannelIds = new Set();

  get allFollowingChannels() {
    const publicChannels = this.chatChannelsManager.publicMessageChannels;
    const dmChannels = this.chatChannelsManager.directMessageChannels;
    return [...publicChannels, ...dmChannels];
  }

  get filteredChannels() {
    const filterStr = String(this.filter ?? "").trim();
    if (filterStr === "") {
      return this.allFollowingChannels;
    }

    const filterLower = filterStr.toLowerCase();
    return this.allFollowingChannels.filter((channel) => {
      const title = channel.title?.toLowerCase() || "";
      const slug = channel.slug?.toLowerCase() || "";
      return title.includes(filterLower) || slug.includes(filterLower);
    });
  }

  @action
  onFilterInput(eventOrValue) {
    // FilterInput passes the event object, not the string value
    const value =
      typeof eventOrValue === "string"
        ? eventOrValue
        : eventOrValue?.target?.value || "";
    this.filter = value;
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
          <div class="manage-starred-channels__filter">
            <FilterInput
              @value={{this.filter}}
              @filterAction={{this.onFilterInput}}
              @icons={{hash left="magnifying-glass"}}
              placeholder={{i18n
                "chat.manage_starred_channels.filter_placeholder"
              }}
            />
          </div>

          <div class="manage-starred-channels__list">
            {{#if this.filteredChannels.length}}
              {{#each this.filteredChannels as |channel|}}
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
                {{#if this.filter}}
                  {{i18n "chat.manage_starred_channels.no_results"}}
                {{else}}
                  {{i18n "chat.manage_starred_channels.no_channels"}}
                {{/if}}
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
