import RouteTemplate from "ember-route-template";
import ApiKeysList from "admin/components/admin-config-areas/api-keys-list";

export default <template>
  <ApiKeysList @apiKeys={{@controller.model.content}} />
</template>
