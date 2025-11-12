import WebhooksList from "discourse/admin/components/admin-config-areas/webhooks-list";

export default <template>
  <WebhooksList @webhooks={{@controller.model}} />
</template>
