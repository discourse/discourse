import ReviewableChatMessage from "../reviewable-chat-message";

<template>
  <ReviewableChatMessage @reviewable={{@reviewable}}>
    {{yield}}
  </ReviewableChatMessage>
</template>
