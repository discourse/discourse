import Component from "@glimmer/component";
import type Owner from "@ember/owner";
import { block } from "discourse/blocks";
import type { BlockDataComponent } from "discourse/blocks/types";
import { i18n } from "discourse-i18n";
import ChatChannelCard from "discourse/plugins/chat/discourse/components/chat-channel-card";
import type ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";
import ChannelCardThumbnail from "./thumbnails/channel-card";

interface ChatChannelCardBlockSignature {
  Args: {
    Named: {
      channelId?: number;
      showMembershipButton?: boolean;
      // Injected by the framework: the data-region boundary, already curried
      // with the resolved chat channel (see `block-layout-wrapper`).
      Data: BlockDataComponent<ChatChannel>;
    };
  };
}

/**
 * A card for a single hand-picked chat channel, resolved by id. Reuses the
 * chat channel card (with its join/leave control and members link), so the
 * block stays a pure renderer and the resolved channel arrives as `@data`.
 */
@block("chat:channel-card", {
  thumbnail: ChannelCardThumbnail,
  displayName: "Chat channel",
  icon: "d-chat",
  category: "Chat",
  description: "A card for a single hand-picked chat channel.",
  args: {
    channelId: {
      type: "number",
      integer: true,
      min: 1,
      ui: {
        control: "number",
        label: i18n("chat.blocks.channel_card.channel_id"),
        helpText: i18n("chat.blocks.channel_card.channel_id_help"),
      },
    },
    showMembershipButton: {
      type: "boolean",
      default: true,
      ui: {
        control: "toggle",
        label: i18n("chat.blocks.channel_card.show_membership_button"),
      },
    },
  },
  data: {
    request: (args: { channelId?: number }) => ({
      kind: "chat-channel",
      channelId: args.channelId,
    }),
    resolve: (
      descriptor: { channelId?: number },
      { owner }: { owner: Owner }
    ) => {
      if (!descriptor.channelId) {
        return null;
      }

      const manager = owner.lookup(
        "service:chat-channels-manager"
      ) as unknown as {
        find: (
          id: number,
          options: { fetchIfNotFound: boolean }
        ) => Promise<object | undefined>;
      };
      return manager.find(descriptor.channelId, { fetchIfNotFound: true });
    },
  },
})
export default class ChatChannelCardBlock extends Component<ChatChannelCardBlockSignature> {
  <template>
    <div class="d-block-chat-channel-card">
      <@Data>
        <:content as |channel|>
          {{#if channel}}
            <ChatChannelCard
              @channel={{channel}}
              @showMembershipButton={{@showMembershipButton}}
            />
          {{/if}}
        </:content>
        <:empty>
          {{! Intentionally bare — any prompt to configure this block is painted
              by external tooling, never on the render path. }}
          <div class="d-block-chat-channel-card__empty"></div>
        </:empty>
      </@Data>
    </div>
  </template>
}
