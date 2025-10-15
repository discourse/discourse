import { concat } from "@ember/helper";
import AdminAreaSettings from "admin/components/admin-area-settings";

<template>
  <AdminAreaSettings
    @area={{@model.wildcard}}
    @path={{concat "/admin/config/login-and-authentication/" @model.wildcard}}
    @filter={{@controller.filter}}
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @showBreadcrumb={{false}}
  />
</template>
