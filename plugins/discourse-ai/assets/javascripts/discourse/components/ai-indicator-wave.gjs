const indicatorDots = [".", ".", "."];
const AiIndicatorWave = <template>
  {{#if @loading}}
    <span class="ai-indicator-wave">
      {{#each indicatorDots as |dot|}}
        <span class="ai-indicator-wave__dot">{{dot}}</span>
      {{/each}}
    </span>
  {{/if}}
</template>;

export default AiIndicatorWave;
