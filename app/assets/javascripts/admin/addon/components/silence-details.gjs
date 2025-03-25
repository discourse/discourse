<div class="penalty-reason-controls">
  <label>
    <div class="silence-reason-label">
      {{html-safe (i18n "admin.user.silence_reason_label")}}
    </div>
  </label>
  <TextField
    @value={{this.reason}}
    @placeholderKey="admin.user.silence_reason_placeholder"
    class="silence-reason"
  />
</div>

<label>
  <div class="silence-message-label">
    {{i18n "admin.user.silence_message"}}
  </div>
</label>
<Textarea
  @value={{this.message}}
  class="silence-message"
  placeholder={{i18n "admin.user.silence_message_placeholder"}}
/>