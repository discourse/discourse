import iN from "discourse/helpers/i18n";
import htmlSafe from "discourse/helpers/html-safe";
import dIcon from "discourse/helpers/d-icon";
<template><div class="empty-state">
  <span class="empty-state-title">
    {{iN "user.no_bookmarks_title"}}
  </span>
  <div class="empty-state-body">
    <p>
      {{htmlSafe (iN "user.no_bookmarks_body" icon=(dIcon "bookmark"))}}
    </p>
  </div>
</div></template>