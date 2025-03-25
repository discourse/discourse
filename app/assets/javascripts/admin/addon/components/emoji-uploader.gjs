<div class="form-kit">
  <div class="form-kit__container form-kit__field form-kit__field-input-text">
    <label class="form-kit__container-title">
      {{i18n "admin.emoji.name"}}
    </label>
    <div class="form-kit__container-content --large">
      <div class="form-kit__control-input-wrapper">
        <Input
          id="emoji-name"
          class="form-kit__control-input"
          name="name"
          @value={{readonly this.name}}
          {{on "input" (with-event-value (fn (mut this.name)))}}
        />
      </div>
    </div>
  </div>
  <div
    class="form-kit__container form-kit__field form-kit__field-input-combo-box"
  >
    <label class="form-kit__container-title">
      {{i18n "admin.emoji.group"}}
    </label>
    <div class="form-kit__container-content --large">
      <div class="form-kit__control-input-wrapper">
        <ComboBox
          @name="group"
          @id="emoji-group-selector"
          @value={{this.group}}
          @content={{this.newEmojiGroups}}
          @onChange={{action "createEmojiGroup"}}
          @valueProperty={{null}}
          @nameProperty={{null}}
          @options={{hash allowAny=true}}
        />
      </div>
    </div>
  </div>
  <div class="control-group">
    <div class="input">
      <input
        {{did-insert this.uppyUpload.setup}}
        class="hidden-upload-field"
        disabled={{this.uppyUpload.uploading}}
        type="file"
        multiple="true"
        accept=".png,.gif"
      />
      <DButton
        @translatedLabel={{this.buttonLabel}}
        @action={{this.chooseFiles}}
        @disabled={{this.uppyUpload.uploading}}
        class="btn-primary"
      />
    </div>
  </div>
</div>