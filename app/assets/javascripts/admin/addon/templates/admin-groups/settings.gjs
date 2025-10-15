import AdminAreaSettings from "admin/components/admin-area-settings";

<template>
  <AdminAreaSettings
    @categories="groups"
    @path="/admin/groups/settings"
    @filter={{@controller.filter}}
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
  />
</template>
