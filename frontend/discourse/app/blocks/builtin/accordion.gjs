// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";

/**
 * A stack of collapsible sections. Its children are `accordion-item` blocks,
 * each of which owns its own title and disclosure state, so the accordion is
 * just their container. (Exclusive "only one open at a time" behaviour is a
 * later refinement; for now sections open independently.)
 */
@block("accordion", {
  thumbnail: () => import("discourse/blocks/thumbnails/accordion"),
  container: true,
  displayName: "Accordion",
  icon: "bars",
  category: "Layout",
  description: "A stack of collapsible titled sections.",
})
export default class Accordion extends Component {
  <template>
    <div class="d-block-accordion">
      {{#each @children key="key" as |child|}}
        <child.Component />
      {{/each}}
    </div>
  </template>
}
