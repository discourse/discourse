import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { get } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { cancel, next, schedule, throttle } from "@ember/runloop";
import { htmlSafe } from "@ember/template";
import { modifier } from "ember-modifier";
import discourseLater from "discourse-common/lib/later";
import { bind } from "discourse-common/utils/decorators";
import { stackingContextFix } from "discourse/plugins/chat/discourse/lib/chat-ios-hacks";
import {
  checkMessageBottomVisibility,
  checkMessageTopVisibility,
} from "discourse/plugins/chat/discourse/lib/check-message-visibility";
import Virtual from "../lib/virtual";

export default class VirtualList extends Component {
  @tracked range;
  @tracked root;
  @tracked slots = [];

  onScroll = modifier((element) => {
    element.parentNode?.addEventListener("scroll", this.handleScrollThrottled, {
      passive: true,
    });
    element.parentNode?.addEventListener("wheel", this.handleScrollThrottled, {
      passive: true,
    });

    return () => {
      element.parentNode?.removeEventListener(
        "scroll",
        this.handleScrollThrottled
      );
      element.parentNode?.removeEventListener(
        "wheel",
        this.handleScrollThrottled
      );
    };
  });

  onResize = modifier((element, [fn]) => {
    let throttleHandler;
    const observer = new ResizeObserver((entries) => {
      throttleHandler = throttle(this, fn, entries);
    });

    observer.observe(element);

    return () => {
      cancel(throttleHandler);
      observer?.disconnect();
    };
  });

  onRegisterInstance = modifier(() => {
    this.args.registerVirtualInstance(this);
  });

  @bind
  handleScrollThrottled(event, force = true) {
    throttle(this, this.handleScroll, event, force, 150, false);
  }

  @bind
  handleScroll(event, force = true) {
    cancel(this.onScrollEndedHandler);

    if (this.#flushIgnoreNextScroll()) {
      return;
    }

    let offset = Math.abs(this.getOffset());
    const clientSize = this.getClientSize();
    const scrollSize = this.getScrollSize();

    // iOS can have unexpected values due to bouncing scrolling
    if (offset < 0 || offset + clientSize > scrollSize + 1 || !scrollSize) {
      return;
    }

    const height = scrollSize - clientSize;

    const pxToBottom = offset;
    const pxToTop = height - offset;

    if (force) {
      this.virtual.handleScroll(offset, pxToTop);
    }

    this.onScrollEndedHandler = discourseLater(this, this.onScrollEnded, 200);

    next(() => {
      schedule("afterRender", () => {
        this.args.onScroll?.({
          offset,
          clientSize,
          scrollSize,
          pxToTop,
          pxToBottom,
          percentToTop:
            height === 0 ? 100 : Math.round((pxToTop / height) * 100),
          percentToBottom:
            height === 0 ? 0 : Math.round((pxToBottom / height) * 100),
          atBottom: height === 0 ? true : pxToBottom <= 2,
          atTop: height === 0 ? false : pxToTop <= 2,
          event,
          up: this.virtual.direction === "UP",
          down: this.virtual.direction === "DOWN",
          lastVisibleId: this.getLastVisibleId(),
        });
      });
    });
  }

  @action
  onScrollEnded() {
    this.args.onScrollEnded?.();
  }

  get keeps() {
    return this.args.keeps ?? 20;
  }

  get estimateSize() {
    return this.args.estimateSize ?? 60;
  }

  get sources() {
    return this.args.sources ?? [];
  }

  @cached
  get wrapperStyle() {
    if (!this.range) {
      return null;
    }

    return htmlSafe(
      `padding: ${this.range.padUp}px 0px ${this.range.padDown}px`
    );
  }

  @cached
  get virtual() {
    return new Virtual(
      {
        keeps: this.keeps,
        estimateSize: this.estimateSize,
        root: this.root,
      },
      this.onRangeChanged
    );
  }

  @bind
  onRangeChanged(range) {
    this.range = range;
    this.computeSlots();
    this.args.onRangeChange(range);
  }

  getOffset() {
    return this.root ? Math.ceil(this.root["scrollTop"]) : 0;
  }

  getClientSize() {
    return this.root ? Math.ceil(this.root["clientHeight"]) : 0;
  }

  getScrollSize() {
    return this.root ? Math.ceil(this.root["scrollHeight"]) : 0;
  }

  @action
  didInsert(element) {
    this.root = element.parentNode;
    this.range = this.virtual.getRange();
  }

  @action
  handleDataSourcesChange() {
    this.computeSlots();
    this.virtual.handleDataSourcesChange(this.sources);
    this.refreshScrollState();
  }

  @action
  refreshScrollState() {
    next(() => {
      schedule("afterRender", () => {
        this._ignoreNextScroll = true;
        this.handleScrollThrottled(null, false);
      });
    });
  }

  scrollToId(id, options = {}) {
    options.position ??= "top";

    return new Promise((resolve) => {
      id = parseInt(id, 10);
      const targetNode = this.args.sources.get(id);

      if (options.position === "top") {
        this.virtual.updateRangeForNode(targetNode);
      } else {
        this.virtual.updateRangeFromNode(targetNode);
      }

      next(() => {
        next(() => {
          schedule("afterRender", () => {
            if (options.position === "top") {
              this._ignoreNextScroll = true;
              this.root
                .querySelector(`:scope [role="group"] > [data-id="${id}"]`)
                .scrollIntoView({
                  block: "start",
                });
            } else {
              this.scrollToOffset(-this.virtual.getOffset(id));
            }

            resolve(targetNode.value);
          });
        });
      });
    });
  }

  #flushIgnoreNextScroll() {
    const prev = this._ignoreNextScroll;
    this._ignoreNextScroll = false;
    return prev;
  }

  @bind
  scrollToTop() {
    schedule("afterRender", () => {
      const scrollSize = this.getScrollSize();
      this.scrollToOffset(-scrollSize);
    });
  }

  @bind
  scrollToBottom() {
    this.scrollToOffset(0);
  }

  scrollToOffset(offset) {
    stackingContextFix(this.root, () => {
      this._ignoreNextScroll = true;
      this.root.scrollTop = -1;
      this.root.scrollTop = offset;
    });
  }

  refresh() {
    next(() => {
      this.virtual.updateRange(
        this.args.sources.first,
        this.args.sources.last,
        true
      );
    });
  }

  computeSlots() {
    if (!this.range) {
      return [];
    }

    const { start, end } = this.range;
    if (!start || !end) {
      return [];
    }

    this.slots = this.args.sources.forRange(start, end).map((node) => {
      return {
        uniqueKey: node.value.id,
        source: node.value,
        resizer: modifier((element, [key]) => {
          let observer = new ResizeObserver((item) => {
            this.onItemResized?.(key, item[0].contentRect.height);
          });
          observer.observe(element);

          return () => {
            observer?.disconnect();
          };
        }),
      };
    });

    this.#checkFill();
    this.refreshScrollState();
  }

  getLastVisibleId() {
    const id = [
      ...this.root.querySelectorAll(":scope [role=group] > [data-id]"),
    ].findLast((item) => checkMessageBottomVisibility(this.root, item))?.dataset
      ?.id;
    return id ? parseInt(id, 10) : null;
  }

  getFirstVisibleId() {
    const id = [
      ...this.root.querySelectorAll(":scope [role=group] > [data-id]"),
    ].find((item) => checkMessageTopVisibility(this.root, item))?.dataset?.id;
    return id ? parseInt(id, 10) : null;
  }

  #checkFill() {
    next(() => {
      schedule("afterRender", () => {
        if (this.getFirstVisibleId() === this.args.sources.first?.value?.id) {
          this.args.onTopNotFilled?.();
          return;
        }
      });
    });
  }

  @action
  onItemResized(id, size) {
    if (size <= 0) {
      return;
    }

    this.virtual.saveSize(id, size);
  }

  <template>
    <div
      role="group"
      class="chat-messages-container"
      style={{this.wrapperStyle}}
      {{this.onScroll}}
      {{didInsert this.didInsert}}
      {{didUpdate this.handleDataSourcesChange @sources}}
      {{this.onRegisterInstance}}
      {{this.onResize @onResize}}
    >
      {{#each this.slots key="uniqueKey" as |slot|}}
        {{yield
          slot
          (get this.slots "0" "source")
          (get this.slots "-1" "source")
        }}
      {{/each}}
    </div>
  </template>
}
