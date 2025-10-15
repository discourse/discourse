import AdminAreaSettings from "admin/components/admin-area-settings";

<template>
  <AdminAreaSettings
    @categories="backups"
    @path="/admin/backups/settings"
    @filter={{@controller.filter}}
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
  />
</template>
