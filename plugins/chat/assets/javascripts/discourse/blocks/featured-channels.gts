import Component from "@glimmer/component";
import type Owner from "@ember/owner";
import { block } from "discourse/blocks";
import type { BlockDataComponent } from "discourse/blocks/types";
import { ajax } from "discourse/lib/ajax";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";
import ChatChannelCard from "discourse/plugins/chat/discourse/components/chat-channel-card";
import type ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";
import FeaturedChannelsThumbnail from "./thumbnails/featured-channels";

interface FeaturedChatChannelsSignature {
  Args: {
    Named: {
      channels?: string;
      browseLink?: boolean;
      browseLabel?: string;
      showMembershipButton?: boolean;
      // Injected by the framework: the data-region boundary, already curried
      // with the resolved chat channels (see `block-layout-wrapper`).
      Data: BlockDataComponent<ChatChannel[]>;
    };
  };
}

/**
 * A grid of selected chat channel cards. The `channels` arg is a
 * pipe-separated string of channel IDs, so the same value can be pasted
 * across sites. The cards are fetched in one request (guardian-scoped) and
 * rendered in the configured order, with an optional "browse all" footer.
 */
@block("chat:featured-channels", {
  thumbnail: FeaturedChannelsThumbnail,
  displayName: "Featured chat channels",
  icon: "d-chat",
  category: "Chat",
  description: "A grid of selected chat channel cards.",
  args: {
    channels: {
      type: "string",
      default: "",
      ui: {
        label: i18n("chat.blocks.featured_channels.channels"),
        helpText: i18n("chat.blocks.featured_channels.channels_help"),
      },
    },
    browseLink: {
      type: "boolean",
      default: true,
      ui: {
        control: "toggle",
        label: i18n("chat.blocks.featured_channels.browse_link"),
      },
    },
    browseLabel: {
      type: "string",
      default: "Browse all channels",
      ui: { label: i18n("chat.blocks.featured_channels.browse_label") },
    },
    showMembershipButton: {
      type: "boolean",
      default: true,
      ui: {
        control: "toggle",
        label: i18n("chat.blocks.featured_channels.show_membership_button"),
      },
    },
  },
  data: {
    request: (args: { channels?: string }) => ({
      kind: "chat-channels",
      channels: args.channels ?? "",
    }),
    resolve: async (
      descriptor: { channels: string },
      { owner }: { owner: Owner }
    ) => {
      const ids = descriptor.channels
        .split("|")
        .map((raw) => parseInt(raw, 10))
        .filter((id) => !Number.isNaN(id));
      if (!ids.length) {
        return null;
      }

      // Fetch the curated set in one guardian-scoped request. We hit the
      // endpoint directly (rather than the tracked `Collection`) and hydrate
      // models only after the await, so no tracked state is mutated inside the
      // data-region's tracked computation.
      const response = (await ajax("/chat/api/channels", {
        data: { channel_ids: ids, limit: ids.length },
      })) as { channels: object[] };

      const manager = owner.lookup(
        "service:chat-channels-manager"
      ) as unknown as {
        store: (channel: object) => ChatChannel;
      };
      const byId = new Map<number, ChatChannel>();
      for (const channelJson of response.channels) {
        const model = manager.store(channelJson);
        byId.set(model.id, model);
      }

      // Preserve the configured order; the server is free to return the
      // guardian-visible subset in any order.
      const ordered = ids
        .map((id) => byId.get(id))
        .filter((channel): channel is ChatChannel => Boolean(channel));
      return ordered.length ? ordered : null;
    },
    skeleton: () => ({ variant: "rect", count: 3 }),
  },
})
export default class FeaturedChatChannels extends Component<FeaturedChatChannelsSignature> {
  <template>
    <div class="d-block-featured-chat-channels">
      <@Data>
        <:content as |channels|>
          <div class="d-block-featured-chat-channels__grid">
            {{#each channels key="id" as |channel|}}
              <ChatChannelCard
                @channel={{channel}}
                @showMembershipButton={{@showMembershipButton}}
              />
            {{/each}}
          </div>

          {{#if @browseLink}}
            <div class="d-block-featured-chat-channels__footer">
              <a
                class="d-block-featured-chat-channels__browse btn btn-default"
                href={{getURL "/chat/browse"}}
              >
                {{@browseLabel}}
              </a>
            </div>
          {{/if}}
        </:content>
        <:empty>
          {{! Intentionally bare — any prompt to configure this block is painted
              by external tooling, never on the render path. }}
          <div class="d-block-featured-chat-channels__empty"></div>
        </:empty>
      </@Data>
    </div>
  </template>
}
