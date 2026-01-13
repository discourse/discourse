import AdminPluginConfigPage from "discourse/admin/components/admin-plugin-config-page";

export default <template>
  <AdminPluginConfigPage @plugin={{@controller.model}}>
    {{outlet}}
  </AdminPluginConfigPage>
</template>
