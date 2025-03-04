import htmlSafe from "discourse/helpers/html-safe";
import iN from "discourse/helpers/i18n";
<template>
  <div class="empty-state">
    <span class="empty-state-title">
      {{iN "user.no_other_notifications_title"}}
    </span>
    <div class="empty-state-body">
      <p>
        {{htmlSafe (iN "user.no_other_notifications_body")}}
      </p>
    </div>
  </div>
</template>
