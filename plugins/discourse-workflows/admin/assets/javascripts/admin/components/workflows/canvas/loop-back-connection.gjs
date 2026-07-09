import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { trustHTML } from "@ember/template";

const SVG_STYLE = trustHTML(
  "overflow:visible;position:absolute;pointer-events:none;width:9999px;height:9999px"
);

function handleAdd(callback, loopNodeClientId, e) {
  e.stopPropagation();
  e.preventDefault();
  callback?.(loopNodeClientId);
}

export default <template>
  <svg class="workflow-loop-back" style={{SVG_STYLE}}>
    <path
      class="workflow-loop-back__path"
      fill="none"
      stroke="var(--primary-low-mid)"
      stroke-width="1.5"
      d={{@entry.pathD}}
    />
    <polygon
      class="workflow-loop-back__arrow"
      fill="var(--primary-low-mid)"
      points={{@entry.loopArrowPoints}}
    />
    <foreignObject
      class="workflow-loop-back__button-fo"
      width="28"
      height="28"
      x={{@entry.loopButtonX}}
      y={{@entry.loopButtonY}}
    >
      <button
        type="button"
        class="workflow-loop-back__add-btn"
        {{on "click" (fn handleAdd @onAdd @entry.loopNodeClientId)}}
      >+</button>
    </foreignObject>
  </svg>
</template>
