import iN from "discourse/helpers/i18n";
import htmlSafe from "discourse/helpers/html-safe";
import getUrl from "discourse/helpers/get-url";
<template><div class="empty-state">
  <span class="empty-state-title">
    {{iN "user.no_likes_title"}}
  </span>
  <div class="empty-state-body">
    <p>
      {{htmlSafe (iN "user.no_likes_body" preferencesUrl=(getUrl "/my/preferences/notifications"))}}
    </p>
  </div>
</div></template>