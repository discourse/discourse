import { LinkTo } from "@ember/routing";
import { and } from "discourse/truth-helpers";
import ChannelTitle from "discourse/plugins/chat/discourse/components/channel-title" with {
  discourseImport: "optional",
};

<template>
  {{#if (and @event.channel ChannelTitle)}}
    <section class="event__section event-chat-channel">
      <span></span>
      <LinkTo
        @route="chat.channel"
        @models={{@event.channel.routeModels}}
        class="chat-channel-link"
      >
        <ChannelTitle @channel={{@event.channel}} />
      </LinkTo>
    </section>
  {{/if}}
</template>
