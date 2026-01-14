import ApiKeysList from "discourse/admin/components/admin-config-areas/api-keys-list";

export default <template>
  <ApiKeysList @apiKeys={{@controller.model.content}} />
</template>
