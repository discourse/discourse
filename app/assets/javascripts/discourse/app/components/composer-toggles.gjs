<div class="composer-controls">
  <span>
    <PluginOutlet @name="before-composer-toggles" @connectorTagName="div" />
  </span>

  {{#if this.site.mobileView}}
    <DButton
      @icon="bars"
      @action={{this.toggleToolbar}}
      @title={{this.toggleToolbarTitle}}
      @preventFocus={{true}}
      class="btn-flat toggle-toolbar btn-mini-toggle"
    />
  {{/if}}

  {{#if this.showFullScreenButton}}
    <DButton
      @icon={{this.fullscreenIcon}}
      @action={{this.toggleFullscreen}}
      @title={{this.fullscreenTitle}}
      class="btn-transparent toggle-fullscreen btn-mini-toggle"
    />
  {{/if}}

  <DButton
    @icon={{this.toggleIcon}}
    @action={{this.toggleComposer}}
    @title={{this.toggleTitle}}
    class="btn-transparent toggler toggle-minimize btn-mini-toggle"
  />
</div>