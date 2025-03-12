{{#each this.buttons as |b|}}
  <button
    type="button"
    class="btn btn-social {{b.name}}"
    {{on "click" (action this.externalLogin b)}}
    aria-label={{b.screenReaderTitle}}
  >
    {{#if b.isGoogle}}
      <GoogleIcon />
    {{else if b.icon}}
      {{d-icon b.icon}}
    {{else}}
      {{d-icon "right-to-bracket"}}
    {{/if}}
    <span class="btn-social-title">{{b.title}}</span>
  </button>
{{/each}}

{{#if this.showPasskeysButton}}
  <PasskeyLoginButton @passkeyLogin={{this.passkeyLogin}} />
{{/if}}

<PluginOutlet @name="after-login-buttons" />