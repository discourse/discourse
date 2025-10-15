import Channel from "discourse/plugins/chat/discourse/components/chat/routes/channel";

<template>
  <Channel
    @channel={{@controller.model}}
    @targetMessageId={{@controller.targetMessageId}}
  />
</template>
