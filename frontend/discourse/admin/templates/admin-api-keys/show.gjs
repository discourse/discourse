import ApiKeysShow from "discourse/admin/components/admin-config-areas/api-keys-show";

export default <template>
  <ApiKeysShow @apiKey={{@controller.model}} />
</template>
