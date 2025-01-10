{{! template-lint-disable no-pointer-down-event-binding }}
{{! template-lint-disable no-invalid-interactive }}

<div class="chat-composer__wrapper">
  {{#if this.shouldRenderMessageDetails}}
    <ChatComposerMessageDetails
      @message={{if this.draft.editing this.draft this.draft.inReplyTo}}
      @cancelAction={{this.resetDraft}}
    />
  {{/if}}

  <div
    role="region"
    aria-label={{i18n "chat.aria_roles.composer"}}
    class={{concat-class
      "chat-composer"
      (if this.isFocused "is-focused")
      (if this.pane.sending "is-sending")
      (if this.sendEnabled "is-send-enabled" "is-send-disabled")
      (if this.disabled "is-disabled" "is-enabled")
      (if this.draft.draftSaved "is-draft-saved" "is-draft-unsaved")
    }}
    {{did-update this.didUpdateMessage this.draft}}
    {{did-update this.didUpdateInReplyTo this.draft.inReplyTo}}
    {{did-insert this.setup}}
    {{will-destroy this.teardown}}
    {{will-destroy this.cancelPersistDraft}}
  >
    <div class="chat-composer__outer-container">
      {{#if this.site.mobileView}}
        <ChatComposerDropdown
          @buttons={{this.dropdownButtons}}
          @isDisabled={{this.disabled}}
        />
      {{/if}}

      <div class="chat-composer__inner-container">
        {{#if this.site.desktopView}}
          <ChatComposerDropdown
            @buttons={{this.dropdownButtons}}
            @isDisabled={{this.disabled}}
          />
        {{/if}}

        <div
          class="chat-composer__input-container"
          {{on "click" this.composer.focus}}
        >
          <DTextarea
            id={{this.composerId}}
            value={{readonly this.draft.message}}
            type="text"
            class="chat-composer__input"
            disabled={{this.disabled}}
            autocorrect="on"
            autocapitalize="sentences"
            placeholder={{this.placeholder}}
            rows={{1}}
            {{did-insert this.setupTextareaInteractor}}
            {{on "input" this.onInput}}
            {{on "keydown" this.onKeyDown}}
            {{on "focusin" this.onTextareaFocusIn}}
            {{on "focusout" this.onTextareaFocusOut}}
            {{did-insert this.setupAutocomplete}}
            data-chat-composer-context={{this.context}}
          />
        </div>

        {{#if this.inlineButtons.length}}
          {{#each this.inlineButtons as |button|}}
            <Chat::Composer::Button
              @icon={{button.icon}}
              class="-{{button.id}}"
              disabled={{or this.disabled button.disabled}}
              tabindex={{if button.disabled -1 0}}
              {{on "click" (fn this.handleInlineButtonAction button.action)}}
              {{on "focus" (fn this.computeIsFocused true)}}
              {{on "blur" (fn this.computeIsFocused false)}}
            />
          {{/each}}

        {{/if}}

        <PluginOutlet
          @name="chat-composer-inline-buttons"
          @outletArgs={{hash composer=this channel=@channel}}
        />

        {{#if this.site.desktopView}}
          <Chat::Composer::Button
            @icon="paper-plane"
            class="-send"
            title={{i18n "chat.composer.send"}}
            disabled={{or this.disabled (not this.sendEnabled)}}
            tabindex={{if this.sendEnabled 0 -1}}
            {{on "click" this.onSend}}
            {{on "mousedown" this.trapMouseDown}}
            {{on "focus" (fn this.computeIsFocused true)}}
            {{on "blur" (fn this.computeIsFocused false)}}
          />
        {{/if}}
      </div>
      {{#if this.site.mobileView}}
        <Chat::Composer::Button
          @icon="paper-plane"
          class="-send"
          title={{i18n "chat.composer.send"}}
          disabled={{or this.disabled (not this.sendEnabled)}}
          tabindex={{if this.sendEnabled 0 -1}}
          {{on "click" this.onSend}}
          {{on "mousedown" this.trapMouseDown}}
          {{on "focus" (fn this.computeIsFocused true)}}
          {{on "blur" (fn this.computeIsFocused false)}}
        />
      {{/if}}
    </div>
  </div>

  {{#if this.canAttachUploads}}
    <ChatComposerUploads
      @fileUploadElementId={{this.fileUploadElementId}}
      @onUploadChanged={{this.onUploadChanged}}
      @existingUploads={{this.draft.uploads}}
      @uploadDropZone={{@uploadDropZone}}
      @composerInputEl={{this.composer.textarea.element}}
    />
  {{/if}}

  <div class="chat-replying-indicator-container">
    <ChatReplyingIndicator @presenceChannelName={{this.presenceChannelName}} />
  </div>
</div>