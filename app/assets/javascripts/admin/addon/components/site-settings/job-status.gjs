import { concat } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import { i18n } from "discourse-i18n";

<template>
  {{#if @status}}
    <div class="desc site-setting">{{htmlSafe
        (i18n (concat "admin.site_settings.job_status." @status))
      }}</div>
  {{/if}}
</template>
