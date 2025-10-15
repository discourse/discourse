import AdminAreaSettings from "admin/components/admin-area-settings";

<template>
  <AdminAreaSettings
    @area="sharing"
    @path="/admin/config/content/sharing"
    @filter={{@controller.filter}}
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @showBreadcrumb={{false}}
  />
</template>
