<<<<<<< HEAD
<div class="empty-state">
  <span class="empty-state-title">
    {{i18n "user_menu.no_chat_notifications_title"}}
  </span>
  <div class="empty-state-body">
    <p>
      {{html-safe
        (i18n
          "user_menu.no_chat_notifications_body"
          preferencesUrl=(get-url "/my/preferences/notifications")
        )
      }}
    </p>
  </div>
</div>
=======
import templateOnly from "@ember/component/template-only";

export default templateOnly();
>>>>>>> a9ddbde3f6 (DEV: [gjs-codemod] renamed js to gjs)
