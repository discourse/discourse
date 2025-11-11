import WebhooksForm from "admin/components/admin-config-areas/webhooks-form";

export default <template>
  <WebhooksForm @webhook={{@controller.model}} />
</template>
