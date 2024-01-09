const ChatNavbarSubTitle = <template>
  <div class="c-navbar__sub-title">
    {{#if (has-block)}}
      {{yield}}
    {{else}}
      {{@title}}
    {{/if}}
  </div>
</template>;

export default ChatNavbarSubTitle;
