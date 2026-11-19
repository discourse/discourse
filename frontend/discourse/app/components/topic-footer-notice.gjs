export default <template>
  {{#if (and @topic.footer_staff_notice (not @topic.isPrivateMessage))}}
    <aside class="alert alert-info topic-footer-notice">
      {{@topic.footer_staff_notice}}
    </aside>
  {{/if}}
</template>
