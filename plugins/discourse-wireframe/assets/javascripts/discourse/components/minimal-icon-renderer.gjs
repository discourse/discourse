// @ts-check
import dIcon from "discourse/ui-kit/helpers/d-icon";

/**
 * Default "live" implementation of the icon inner-content component
 * yielded as `R.Content` by `IconRenderer`. Emits just the icon glyph
 * — no scaffold, no data-attrs. This is what every viewer page
 * renders. When `@value` is empty, nothing renders (matching today's
 * `{{#if @icon}}{{dIcon @icon}}{{/if}}` pattern in block templates).
 *
 * The editor-aware variant lives in admin code
 * (`admin/.../components/scaffolded-icon-renderer.gjs`) and the
 * wireframe service swaps it in via `blockArgRenderers["icon"]` when
 * the editor opens. Block templates always use the public
 * `IconRenderer` wrapper; the implementation swap is opaque to them.
 */
const MinimalIconRenderer = <template>
  {{~#if @value~}}
    {{dIcon @value}}
  {{~/if~}}
</template>;

export default MinimalIconRenderer;
