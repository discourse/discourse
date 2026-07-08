import { fn } from "@ember/helper";
import { trustHTML } from "@ember/template";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import ConnectionToolbar from "./connection-toolbar";

const SVG_STYLE = trustHTML(
  "overflow:visible;position:absolute;pointer-events:none;width:9999px;height:9999px"
);

export default <template>
  <svg
    class={{dConcatClass "workflow-connection" (if @entry.isPseudo "--pseudo")}}
    style={{SVG_STYLE}}
  >
    <path
      class="workflow-connection__hit"
      fill="none"
      stroke="transparent"
      stroke-width="12"
      pointer-events="stroke"
      style="cursor:pointer"
      d={{@entry.pathD}}
    />
    <path
      class="workflow-connection__visible"
      fill="none"
      stroke={{if @entry.isPseudo "var(--tertiary)" "var(--primary-low-mid)"}}
      stroke-width="1.5"
      stroke-dasharray={{if @entry.isPseudo "6 3" ""}}
      opacity={{if @entry.isPseudo "0.6" ""}}
      d={{@entry.pathD}}
    />
    <path
      class="workflow-connection__arrow"
      d="M -9 -5 L 0 0 L -9 5 Z"
      fill={{if @entry.isPseudo "var(--tertiary)" "var(--primary-low-mid)"}}
      stroke={{if @entry.isPseudo "var(--tertiary)" "var(--primary-low-mid)"}}
      stroke-width="2"
      stroke-linejoin="round"
      transform={{@entry.arrowTransform}}
    />
    {{#unless @entry.isPseudo}}
      <foreignObject
        class="workflow-connection__toolbar-fo"
        width="48"
        height="22"
        x={{@entry.toolbarX}}
        y={{@entry.toolbarY}}
      >
        <ConnectionToolbar
          @hitPathSelector=".workflow-connection__hit"
          @foreignObjectSelector=".workflow-connection__toolbar-fo"
          @svgElement={{@entry.element}}
          @onAdd={{fn @onAdd @entry.connectionInfo}}
          @onDelete={{fn @onDelete @entry.connectionInfo}}
        />
      </foreignObject>
    {{/unless}}
  </svg>
</template>
