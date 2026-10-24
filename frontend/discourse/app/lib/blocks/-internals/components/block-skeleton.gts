import Component from "@glimmer/component";
import type { BlockSkeletonShape } from "discourse/blocks/types";
import DSkeleton from "discourse/ui-kit/d-skeleton";

interface BlockSkeletonSignature {
  Args: {
    /** The reserved-space shape declared by the block's `skeleton` hint. */
    shape: BlockSkeletonShape;
  };
}

const DEFAULT_ROW_COUNT = 5;

/*
 * The default loading placeholder of a block's data region. A shape with
 * `rows` paints composed list rows that a plain `DSkeleton` cannot express;
 * any other shape is forwarded to `DSkeleton` as is.
 */
export default class BlockSkeleton extends Component<BlockSkeletonSignature> {
  get rows(): number[] {
    const count = this.args.shape.count ?? DEFAULT_ROW_COUNT;
    return Array.from({ length: count }, (_, index) => index);
  }

  get isUser(): boolean {
    return this.args.shape.rows === "user";
  }

  get isLink(): boolean {
    return this.args.shape.rows === "link";
  }

  get isTopic(): boolean {
    return this.args.shape.rows === "topic";
  }

  <template>
    {{#if @shape.rows}}
      <div aria-hidden="true" class="block-skeleton">
        {{#each this.rows as |row|}}
          <div class="block-skeleton__row --{{@shape.rows}}" data-row={{row}}>
            {{#if this.isUser}}
              <DSkeleton
                @size="var(--d-comp-BlockSkeleton-size-avatar)"
                @variant="circle"
              />
              <DSkeleton @variant="text" @width="55%" />
              <DSkeleton
                @variant="text"
                @width="var(--d-comp-BlockSkeleton-score-size-inline)"
              />
            {{else if this.isLink}}
              <DSkeleton
                @size="var(--d-comp-BlockSkeleton-size-icon)"
                @variant="rect"
              />
              <div class="block-skeleton__lines">
                <DSkeleton @variant="text" @width="60%" />
                <DSkeleton @variant="text" @width="85%" />
              </div>
            {{else if this.isTopic}}
              <div class="block-skeleton__lines">
                <DSkeleton @variant="text" @width="90%" />
                <DSkeleton @variant="text" @width="40%" />
              </div>
            {{/if}}
          </div>
        {{/each}}
      </div>
    {{else}}
      <DSkeleton
        @count={{@shape.count}}
        @height={{@shape.height}}
        @variant={{@shape.variant}}
        @width={{@shape.width}}
      />
    {{/if}}
  </template>
}
