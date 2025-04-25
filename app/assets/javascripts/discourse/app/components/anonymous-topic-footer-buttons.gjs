<div class="topic-footer-main-buttons">
  {{#each this.buttons as |button|}}
    <DButton
      @action={{button.action}}
      @icon={{button.icon}}
      @translatedLabel={{button.label}}
      @translatedTitle={{button.title}}
      @translatedAriaLabel={{button.ariaLabel}}
      @disabled={{button.disabled}}
      id={{concat "topic-footer-button-" button.id}}
      class={{concatClass
        "btn-default"
        "topic-footer-button"
        button.classNames
      }}
    />
  {{/each}}
  <DButton
    @icon="reply"
    @action={{route-action "showLogin"}}
    @label="topic.reply.title"
    class="btn-primary"
  />
</div>