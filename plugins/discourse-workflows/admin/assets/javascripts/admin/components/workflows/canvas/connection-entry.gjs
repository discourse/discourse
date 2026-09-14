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
      d={{@entry.pathD}}
      fill="none"
      pointer-events="stroke"
      stroke="transparent"
      stroke-width="12"
      style="cursor:pointer"
    />
    <path
      class="workflow-connection__visible"
      d={{@entry.pathD}}
      fill="none"
      opacity={{if @entry.isPseudo "0.6" ""}}
      stroke={{if @entry.isPseudo "var(--tertiary)" "var(--primary-low-mid)"}}
      stroke-dasharray={{if @entry.isPseudo "6 3" ""}}
      stroke-width="1.5"
    />
    <path
      class="workflow-connection__arrow"
      d="M -9 -5 L 0 0 L -9 5 Z"
      fill={{if @entry.isPseudo "var(--tertiary)" "var(--primary-low-mid)"}}
      stroke={{if @entry.isPseudo "var(--tertiary)" "var(--primary-low-mid)"}}
      stroke-linejoin="round"
      stroke-width="2"
      transform={{@entry.arrowTransform}}
    />
    {{#unless @entry.isPseudo}}
      <foreignObject
        class="workflow-connection__toolbar-fo"
        height="22"
        width="48"
        x={{@entry.toolbarX}}
        y={{@entry.toolbarY}}
      >
        <ConnectionToolbar
          @foreignObjectSelector=".workflow-connection__toolbar-fo"
          @hitPathSelector=".workflow-connection__hit"
          @onAdd={{fn @onAdd @entry.connectionInfo}}
          @onDelete={{fn @onDelete @entry.connectionInfo}}
          @svgElement={{@entry.element}}
        />
      </foreignObject>
    {{/unless}}
  </svg>
</template>
