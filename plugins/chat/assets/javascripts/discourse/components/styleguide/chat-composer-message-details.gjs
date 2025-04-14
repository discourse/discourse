<StyleguideExample @title="<ChatComposerMessageDetails>">
  <Styleguide::Component>
    <ChatComposerMessageDetails @message={{this.message}} />
  </Styleguide::Component>

  <Styleguide::Controls>
    <Styleguide::Controls::Row @name="Mode">
      {{#if this.message.editing}}
        <DButton @action={{this.toggleMode}} @translatedLabel="Reply" />
      {{else}}
        <DButton @action={{this.toggleMode}} @translatedLabel="Editing" />
      {{/if}}
    </Styleguide::Controls::Row>
  </Styleguide::Controls>
</StyleguideExample>