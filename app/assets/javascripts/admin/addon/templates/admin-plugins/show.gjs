import AdminPluginConfigPage from "admin/components/admin-plugin-config-page";

<template>
  <AdminPluginConfigPage @plugin={{@controller.model}}>
    {{outlet}}
  </AdminPluginConfigPage>
</template>
