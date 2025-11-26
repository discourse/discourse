import PluginOutlet from "discourse/components/plugin-outlet";

export default <template>
  <div class="admin-webhooks admin-config-page">
    <PluginOutlet @name="admin-web-hooks">
      {{outlet}}
    </PluginOutlet>
  </div>
</template>
