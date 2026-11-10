export default <template>
  {{#if @outletArgs.message.aiLlmName}}
    <span class="ai-chat-message__model">
      {{@outletArgs.message.aiLlmName}}
    </span>
  {{/if}}
</template>
