import DTooltip from "discourse/float-kit/components/d-tooltip";

export default <template>
  <div class="site-traffic-detail__metric {{if @primary '--primary'}}">
    <span class="site-traffic-detail__metric-copy" ...attributes>
      <span class="site-traffic-detail__metric-label">{{@label}}</span>
      <span class="site-traffic-detail__metric-value">{{@value}}</span>
    </span>
    {{#if @tooltip}}
      <DTooltip
        class="site-traffic-detail__metric-tooltip"
        @identifier={{@tooltipIdentifier}}
        @icon="far-circle-question"
      >
        <:content>{{@tooltip}}</:content>
      </DTooltip>
    {{/if}}
  </div>
</template>
