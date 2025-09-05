import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { service } from "@ember/service";

export default class ImageGrid extends Component {
  static EXCLUDED_NODE_NAMES = ["BR", "P"];

  @service site;

  #items = this.#prepareItems(this.args.data.wrappedElements);

  get columnCount() {
    return [2, 4].includes(this.#items.length) || this.site.mobileView ? 2 : 3;
  }

  @cached
  get columns() {
    const count = this.columnCount;
    return this.#distributeColumnsEvenly(this.#items, count);
  }

  // Helper used by template to detect direct images
  isImg(node) {
    return node?.nodeName === "IMG";
  }

  // Compute columns using aspect-ratio "masonry" distribution
  #distributeColumnsEvenly(items, columnCount) {
    const columns = Array.from({ length: columnCount }, () => []);
    const heights = Array(columnCount).fill(0);

    items.forEach((item) => {
      const shortestIndex = this.#indexOfShortest(heights);
      heights[shortestIndex] += this.#aspectRatio(item);
      columns[shortestIndex].push(item);
    });

    return columns;
  }

  // Find index of the shortest column height
  #indexOfShortest(heights) {
    let idx = 0;
    for (let j = 1; j < heights.length; j++) {
      if (heights[j] < heights[idx]) {
        idx = j;
      }
    }
    return idx;
  }

  // Calculate aspect ratio used for "height" heuristic
  #aspectRatio(item) {
    // use aspect ratio to compare heights and append to shortest column
    // if element is not an image, assume ratio is 1:1
    const img = item.querySelector?.("img") || item;
    return img?.nodeName === "IMG" && img.width ? img.height / img.width : 1;
  }

  #isParagraphWithChildren(node) {
    return node?.nodeName === "P" && node.children?.length > 0;
  }

  #prepareItems(wrappedElements) {
    const targets = [];

    for (const element of wrappedElements) {
      if (this.#isParagraphWithChildren(element)) {
        // unwrap the paragraph children and add them to the target list
        for (let nested of element.children) {
          targets.push(nested);
        }
      } else {
        targets.push(element);
      }
    }

    return targets.filter(
      (node) => !ImageGrid.EXCLUDED_NODE_NAMES.includes(node.nodeName)
    );
  }

  <template>
    <div class="d-image-grid" data-columns={{this.columnCount}}>
      {{#each this.columns as |column|}}
        <div class="d-image-grid-column">
          {{#each column as |item|}}
            {{#if (this.isImg item)}}
              <span class="image-wrapper">
                {{item}}
              </span>
            {{else}}
              {{item}}
            {{/if}}
          {{/each}}
        </div>
      {{/each}}
    </div>
  </template>
}
