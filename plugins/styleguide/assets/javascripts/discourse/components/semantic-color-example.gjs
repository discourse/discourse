const SemanticColorExample = <template>
  <section class="semantic-color-example">
    <div class="semantic-color-swatch {{@color}}"></div>
    <div class="semantic-color-info">
      <div class="semantic-color-var">var(--{{@color}})</div>
      {{#if @description}}
        <div class="semantic-color-desc">{{@description}}</div>
      {{/if}}
    </div>
  </section>
</template>;

export default SemanticColorExample;
