import Component from "@glimmer/component";

const DEFAULT_ROWS = 3;

/*
 * Reserved-space placeholder shown while a block's data is loading. Rendering a
 * few rows sized close to the eventual content keeps the block's footprint
 * stable, so revealing the loaded content doesn't shift the surrounding layout.
 * The shimmer comes from the shared `.placeholder-animation` class.
 */
export default class DBlockSkeleton extends Component {
  get rows() {
    const requested = this.args.rows ?? DEFAULT_ROWS;
    const count = Math.max(1, Math.floor(requested));
    return Array.from({ length: count }, (_, index) => index);
  }

  <template>
    <div class="d-block-skeleton" aria-hidden="true" ...attributes>
      {{#if @title}}
        <div class="d-block-skeleton__title placeholder-animation"></div>
      {{/if}}
      {{#each this.rows key="@index"}}
        <div class="d-block-skeleton__row placeholder-animation"></div>
      {{/each}}
    </div>
  </template>
}
