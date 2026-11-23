const RewindWindow = <template>
  <div class="rewind-window" ...attributes>
    <div class="rewind-window__bar">
      <span class="rewind-window__close"></span>
      {{#if @title}}
        <span class="rewind-window__title">{{@title}}</span>
      {{/if}}
    </div>
    <div class="rewind-window__body">
      {{yield}}
    </div>
  </div>
</template>;

export default RewindWindow;
