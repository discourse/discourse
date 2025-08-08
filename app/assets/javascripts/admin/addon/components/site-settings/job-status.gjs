import { htmlSafe } from "@ember/template";
import { eq } from "truth-helpers";
import { i18n } from "discourse-i18n";

<template>
  {{#if @status}}
    <div class="job desc site-setting">
      {{#if (eq @status "enqueued")}}
        <p class="alert">{{htmlSafe
            (i18n "admin.site_settings.job_status.enqueued")
          }}</p>
      {{else if (eq @status "completed")}}
        <p class="success">{{htmlSafe
            (i18n "admin.site_settings.job_status.completed")
          }}</p>
      {{/if}}
      {{#if @progress}}
        <p class="progress">{{htmlSafe @progress}}</p>
      {{/if}}
    </div>
  {{/if}}
</template>
