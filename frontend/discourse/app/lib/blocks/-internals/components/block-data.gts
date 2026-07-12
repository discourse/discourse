import type { TemplateOnlyComponent } from "@ember/component/template-only";
import type { ComponentLike } from "@glint/template";
import type { TrackedAsyncData } from "ember-async-data";
import type { BlockSkeletonShape } from "discourse/blocks/types";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DSkeleton from "discourse/ui-kit/d-skeleton";

interface BlockDataSignature {
  Args: {
    /**
     * The block's coordinated data state, forwarded to the async-content
     * renderer.
     */
    state: TrackedAsyncData<unknown>;

    /** The reserved-space shape for the default loading skeleton. */
    skeletonShape: BlockSkeletonShape;
  };
  Blocks: {
    /** Rendered while the data is pending, overriding the default skeleton. */
    loading: [];

    /** Rendered once resolved, yielding the resolved value. */
    content: [value: unknown];

    /** Rendered instead of content when the resolved value is empty. */
    empty: [];

    /**
     * Rendered on failure, yielding the error and the inline error component
     * the async-content renderer supplies (pre-bound to the error).
     */
    error: [error: Error, inlineError: ComponentLike];
  };
}

/*
 * Data-region boundary a block places around the part of its template that
 * depends on loaded data. The block's chrome (titles, links, headings) stays
 * OUTSIDE this boundary, so it remains visible while the data loads.
 *
 * The framework binds `@state` and `@skeletonShape` for the block (the wrapper
 * hands the block this component already curried, see `block-layout-wrapper`),
 * so a block never wires up the data state itself. It wraps the shared
 * async-content renderer with block-friendly defaults:
 *   - while loading, a reserved-space `DSkeleton` sized from `@skeletonShape`;
 *   - on failure, the inline error the async-content renderer yields.
 *
 * Both defaults are overridable by providing the matching named block
 * (`:loading` / `:error`). The block supplies `:content` (and optionally
 * `:empty`) for the resolved value:
 *
 *   <@Data>
 *     <:content as |topics|><BasicTopicList @topics={{topics}} /></:content>
 *     <:empty>{{i18n "topics.none.latest"}}</:empty>
 *   </@Data>
 */
const BlockData: TemplateOnlyComponent<BlockDataSignature> = <template>
  {{! The boundary stays layout-neutral (display: contents) so it doesn't
      disturb the block's own layout; it carries aria-busy so assistive
      technology is told the region is loading. }}
  <div class="block-data" aria-busy={{if @state.isPending "true" "false"}}>
    <DAsyncContent @asyncData={{@state}}>
      <:loading>
        {{#if (has-block "loading")}}
          {{yield to="loading"}}
        {{else}}
          <DSkeleton
            @variant={{@skeletonShape.variant}}
            @count={{@skeletonShape.count}}
            @width={{@skeletonShape.width}}
            @height={{@skeletonShape.height}}
          />
        {{/if}}
      </:loading>
      <:content as |value|>
        {{yield value to="content"}}
      </:content>
      <:empty>
        {{#if (has-block "empty")}}
          {{yield to="empty"}}
        {{/if}}
      </:empty>
      <:error as |error inlineError|>
        {{#if (has-block "error")}}
          {{yield error inlineError to="error"}}
        {{else}}
          {{! Reuse the inline error the async-content renderer yields, so a
              failed fetch surfaces the standard flash in the data region. }}
          <inlineError />
        {{/if}}
      </:error>
    </DAsyncContent>
  </div>
</template>;

export default BlockData;
