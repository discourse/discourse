import AdminAreaSettings from "admin/components/admin-area-settings";

<template>
  <AdminAreaSettings
    @area="permalinks"
    @path="/admin/config/permalinks/settings"
    @filter={{@controller.filter}}
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
  />
</template>
