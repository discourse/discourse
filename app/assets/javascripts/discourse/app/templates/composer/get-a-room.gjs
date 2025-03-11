<ComposerTipCloseButton @action={{fn this.closeMessage this.message}} />

{{html-safe this.message.body}}

<DButton
  @label="user.private_message"
  @icon="envelope"
  @action={{fn this.switchPM this.message}}
  class="btn-primary"
/>