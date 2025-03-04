import dIcon from "discourse/helpers/d-icon";
import getUrl from "discourse/helpers/get-url";
import htmlSafe from "discourse/helpers/html-safe";
import iN from "discourse/helpers/i18n";
<template><div class="empty-state">
  <span class="empty-state-title">
    {{iN "user.no_messages_title"}}
  </span>
  <div class="empty-state-body">
    <p>
      {{htmlSafe (iN "user.no_messages_body" icon=(dIcon "envelope") aboutUrl=(getUrl "/about"))}}
    </p>
  </div>
</div></template>