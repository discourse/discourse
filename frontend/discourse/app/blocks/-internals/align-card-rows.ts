import { modifier } from "ember-modifier";

interface AlignCardRowsSignature {
  Element: HTMLDivElement;
  Args: {
    Named: {
      /** Parent allocation mode; Stack never synchronizes peers. */
      mode: string;
      /** Opt-out for layouts whose cards should size independently. */
      alignment?: "auto" | "off";
    };
  };
}

type Allocation = {
  element: HTMLElement;
  rect: DOMRect;
  card: HTMLElement | null;
  presentation: string | undefined;
  stretched: boolean;
  spanning: boolean;
};

type CardMeasurement = {
  card: HTMLElement;
  media: number;
  content: number;
  inset: number;
};

const PROPERTIES = [
  "--card-aligned-media",
  "--card-aligned-content",
  "--card-action-inset",
] as const;

function pixels(value: string): number {
  return Number.parseFloat(value) || 0;
}

function sameRow(a: DOMRect, b: DOMRect): boolean {
  return Math.abs(a.top - b.top) < 0.5 && Math.abs(a.bottom - b.bottom) < 0.5;
}

function overlaps(a: DOMRect, b: DOMRect): boolean {
  return (
    Math.min(a.right, b.right) - Math.max(a.left, b.left) > 0.5 &&
    Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top) > 0.5
  );
}

function spansRows(style: CSSStyleDeclaration): boolean {
  const { gridRowStart: start, gridRowEnd: end } = style;
  if (start.startsWith("span ") || end.startsWith("span ")) {
    return pixels((start.startsWith("span ") ? start : end).slice(5)) > 1;
  }
  return Math.abs(Number(end) - Number(start)) > 1;
}

/** Coordinates direct logical Card peers without changing authored layout tracks. */
class CardRowCoordinator {
  #element: HTMLElement;
  #mode: string;
  #frame: number | null = null;
  #disposed = false;
  #resize: ResizeObserver;
  #mutations: MutationObserver;
  #observed = new Set<Element>();
  #aligned = new Set<HTMLElement>();
  #writtenStyles = new WeakMap<HTMLElement, string | null>();

  #loaded = (event: Event): void => {
    if (
      event.target instanceof HTMLLinkElement ||
      (event.target instanceof Node && this.#element.contains(event.target))
    ) {
      this.#schedule();
    }
  };

  #schedule = (): void => {
    if (!this.#disposed && this.#frame === null) {
      this.#frame = requestAnimationFrame(() => {
        this.#frame = null;
        this.#reconcile();
      });
    }
  };

  constructor(element: HTMLElement, mode: string) {
    this.#element = element;
    this.#mode = mode;
    this.#resize = new ResizeObserver(this.#schedule);
    this.#mutations = new MutationObserver((records) => {
      if (
        records.some((record) => {
          const target = record.target;
          return !(
            record.attributeName === "style" &&
            target instanceof HTMLElement &&
            this.#writtenStyles.has(target) &&
            this.#writtenStyles.get(target) === target.getAttribute("style")
          );
        })
      ) {
        this.#schedule();
      }
    });
    this.#mutations.observe(element, {
      subtree: true,
      childList: true,
      characterData: true,
      attributes: true,
      attributeFilter: [
        "class",
        "style",
        "hidden",
        "dir",
        "data-card-presentation",
        "data-block-layout-item",
      ],
    });
    // Theme/section tokens can change without changing a card's allocation.
    for (
      let ancestor = element.parentElement;
      ancestor;
      ancestor = ancestor.parentElement
    ) {
      this.#mutations.observe(ancestor, {
        attributes: true,
        attributeFilter: ["class", "style", "dir"],
      });
    }
    this.#mutations.observe(document.head, {
      subtree: true,
      childList: true,
      characterData: true,
      attributes: true,
      attributeFilter: ["href", "media", "disabled"],
    });
    document.fonts.addEventListener("loadingdone", this.#schedule);
    document.addEventListener("load", this.#loaded, true);
    this.#schedule();
  }

  destroy(): void {
    this.#disposed = true;
    if (this.#frame !== null) {
      cancelAnimationFrame(this.#frame);
    }
    this.#resize.disconnect();
    this.#mutations.disconnect();
    document.fonts.removeEventListener("loadingdone", this.#schedule);
    document.removeEventListener("load", this.#loaded, true);
    for (const card of this.#aligned) {
      this.#clear(card);
    }
    this.#aligned.clear();
    this.#observed.clear();
  }

  #allocations(): Allocation[] {
    const parent =
      this.#mode === "grid"
        ? this.#element
        : this.#element.querySelector<HTMLElement>(
            ":scope > .d-block-layout__flex"
          );
    if (!parent) {
      return [];
    }
    const parentStyle = getComputedStyle(parent);
    return Array.from(parent.children).flatMap((element) => {
      if (
        !(element instanceof HTMLElement) ||
        !element.matches(
          this.#mode === "grid"
            ? ".d-block-layout__cell"
            : "[data-block-layout-item]"
        )
      ) {
        return [];
      }
      const rect = element.getBoundingClientRect();
      if (!rect.width || !rect.height) {
        return [];
      }
      const item =
        this.#mode === "grid"
          ? element.querySelector<HTMLElement>(
              ":scope > [data-block-layout-item]"
            )
          : element;
      const card =
        item?.dataset.blockLayoutItem === "card"
          ? item.querySelector<HTMLElement>("[data-card-presentation]")
          : null;
      const style = getComputedStyle(element);
      const ownAlign =
        style.alignSelf === "auto" ? parentStyle.alignItems : style.alignSelf;
      const stretched =
        ["stretch", "normal"].includes(ownAlign) &&
        (this.#mode !== "grid" ||
          ["stretch", "normal"].includes(style.alignItems));
      return [
        {
          element,
          rect,
          card,
          presentation: card?.dataset.cardPresentation,
          stretched,
          spanning: this.#mode === "grid" && spansRows(style),
        },
      ];
    });
  }

  #measure(card: HTMLElement, observed: Set<Element>): CardMeasurement {
    const media = card.querySelector<HTMLElement>(
      ":scope > .d-block-card__media"
    );
    const content = card.querySelector<HTMLElement>(
      ":scope > .d-block-card__content"
    );
    const copy = content?.querySelector<HTMLElement>(
      ":scope > .d-block-card__copy"
    );
    const actions = content?.querySelector<HTMLElement>(
      ":scope > .d-block-card__actions"
    );
    const identity = media?.querySelector<HTMLElement>(
      ":scope > .d-block-card__identity"
    );
    for (const region of [card, copy, actions, identity]) {
      if (region) {
        observed.add(region);
      }
    }
    const contentStyle = content ? getComputedStyle(content) : null;
    const inset = contentStyle ? pixels(contentStyle.paddingBlockStart) : 0;
    const identityStyle = identity ? getComputedStyle(identity) : null;
    // Offset dimensions stay in CSS pixels under a scaled ancestor.
    const naturalMedia = media
      ? pixels(getComputedStyle(media, "::before").blockSize)
      : 0;
    const identityHeight =
      identity && identityStyle
        ? identity.offsetHeight +
          pixels(identityStyle.marginBlockStart) +
          pixels(identityStyle.marginBlockEnd)
        : 0;
    return {
      card,
      media: Math.max(naturalMedia, identityHeight),
      content:
        (copy?.offsetHeight ?? 0) +
        (actions?.offsetHeight ?? 0) +
        inset +
        (copy && actions && contentStyle ? pixels(contentStyle.rowGap) : 0),
      inset,
    };
  }

  #reconcile(): void {
    const allocations = this.#allocations();
    const observed = new Set<Element>([this.#element]);
    const measurements = new Map<HTMLElement, CardMeasurement>();
    for (const allocation of allocations) {
      observed.add(allocation.element);
      if (allocation.card) {
        measurements.set(
          allocation.card,
          this.#measure(allocation.card, observed)
        );
      }
    }
    const desired = new Map<HTMLElement, number[]>();
    const visited = new Set<Allocation>();
    for (const allocation of allocations) {
      if (visited.has(allocation) || allocation.spanning) {
        continue;
      }
      const row = allocations.filter(
        (peer) => !peer.spanning && sameRow(allocation.rect, peer.rect)
      );
      row.forEach((peer) => visited.add(peer));
      const cards = row.filter((peer) => peer.card && peer.stretched);
      const presentation = cards[0]?.presentation;
      if (
        cards.length < 2 ||
        !["above", "below"].includes(presentation ?? "") ||
        cards.some((peer) => peer.presentation !== presentation) ||
        cards.some((peer) =>
          allocations.some(
            (other) => other !== peer && overlaps(peer.rect, other.rect)
          )
        )
      ) {
        continue;
      }
      const sizes = cards.flatMap((peer) => {
        const measurement = peer.card && measurements.get(peer.card);
        return measurement ? [measurement] : [];
      });
      const inset = Math.max(...sizes.map((size) => size.inset));
      const media = Math.ceil(Math.max(...sizes.map((size) => size.media)));
      const content = Math.ceil(
        Math.max(...sizes.map((size) => size.content + inset))
      );
      for (const size of sizes) {
        desired.set(size.card, [media, content, inset]);
      }
    }
    // All geometry reads finish before any synchronized dimensions are written.
    for (const element of this.#observed) {
      if (!observed.has(element)) {
        this.#resize.unobserve(element);
      }
    }
    for (const element of observed) {
      if (!this.#observed.has(element)) {
        this.#resize.observe(element);
      }
    }
    this.#observed = observed;
    for (const card of this.#aligned) {
      if (!desired.has(card)) {
        this.#clear(card);
      }
    }
    for (const [card, values] of desired) {
      PROPERTIES.forEach((property, index) => {
        const value = `${values[index]}px`;
        if (card.style.getPropertyValue(property) !== value) {
          card.style.setProperty(property, value);
        }
      });
      if (!card.hasAttribute("data-card-aligned")) {
        card.setAttribute("data-card-aligned", "");
      }
      this.#writtenStyles.set(card, card.getAttribute("style"));
    }
    this.#aligned = new Set(desired.keys());
  }

  #clear(card: HTMLElement): void {
    PROPERTIES.forEach((property) => card.style.removeProperty(property));
    card.removeAttribute("data-card-aligned");
    this.#writtenStyles.set(card, card.getAttribute("style"));
  }
}

export default modifier<AlignCardRowsSignature>(
  (element, _, { mode, alignment }) => {
    if (mode === "stack" || alignment === "off") {
      return;
    }
    const coordinator = new CardRowCoordinator(element, mode);
    return () => coordinator.destroy();
  }
);
