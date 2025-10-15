import AdminAreaSettings from "admin/components/admin-area-settings";

<template>
  <AdminAreaSettings
    @area="discourseconnect"
    @path="/admin/config/login-and-authentication/discourse-connect"
    @filter={{@controller.filter}}
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @showBreadcrumb={{false}}
  />
</template>
