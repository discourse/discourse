import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import { action } from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

const HISTORY_LIMIT = 60;
const VISIBLE_LIMIT = 10;

function describeElement(element) {
  if (!element || element === document.body) {
    return "—";
  }

  const parts = [element.tagName.toLowerCase()];
  const role = element.getAttribute("role");
  if (role) {
    parts.push(`role=${role}`);
  }
  const identifier = element.id || element.className?.toString().split(" ")[0];
  if (identifier) {
    parts.push(identifier);
  }
  return parts.join(" · ");
}

function describeRow(element) {
  if (!element) {
    return "—";
  }
  return element.textContent.trim().slice(0, 40) || "(empty)";
}

/**
 * Anything on the path from an option up to the document that could keep it out of the
 * accessibility tree, or wall it off from the control pointing at it.
 */
function describeBarriers(element) {
  if (!element) {
    return "—";
  }

  const found = [];
  for (
    let node = element;
    node && node !== document.body;
    node = node.parentElement
  ) {
    const role = node.getAttribute("role");
    if (role === "dialog" || role === "alertdialog") {
      found.push(`role=${role}`);
    }
    if (node.getAttribute("aria-modal") === "true") {
      found.push("aria-modal");
    }
    if (node.getAttribute("aria-hidden") === "true") {
      found.push("aria-hidden");
    }
    if (node.hasAttribute("inert")) {
      found.push("inert");
    }
    if (node.hasAttribute("popover")) {
      found.push("popover");
    }
  }

  return found.length ? found.join(" > ") : "none";
}

/**
 * Whether the option is reachable from the controller by DOM containment or by an explicit
 * ownership claim. A combobox that points into a subtree it neither contains nor owns is the
 * shape assistive tech is least likely to follow.
 */
function describeContainment(focused, target) {
  if (!focused || !target) {
    return "—";
  }

  if (focused.contains(target)) {
    return "DOM descendant";
  }

  const owns = focused.getAttribute("aria-owns");
  const controls = focused.getAttribute("aria-controls");
  const ownsTarget = owns
    ?.split(/\s+/)
    .some((id) => document.getElementById(id)?.contains(target));
  const controlsTarget = controls
    ?.split(/\s+/)
    .some((id) => document.getElementById(id)?.contains(target));

  const claims = [
    ownsTarget ? "aria-owns" : null,
    controlsTarget ? "aria-controls" : null,
  ].filter(Boolean);

  return claims.length
    ? `portaled, claimed by ${claims.join(" + ")}`
    : "portaled, UNCLAIMED";
}

/**
 * A live readout of the ARIA state a screen reader would be working from, recorded as a
 * timeline rather than a single snapshot.
 *
 * Announcement bugs are hard to chase because the only evidence is what someone heard, and the
 * candidate causes sound identical from the outside: a cursor that never moved, a cursor
 * pointing at an id that does not resolve, state that is exposed but never voiced, and a
 * message the channel silently declined to deliver. A snapshot cannot separate them because
 * each one is a claim about a *sequence* — what the third arrow press did, whether the second
 * identical message reached the DOM. Every entry is also written to the console, so a session
 * can be read back after the fact instead of transcribed while it happens.
 *
 * Two independent sources feed one timeline:
 *
 * - focus/key/pointer events, reported after the render they trigger;
 * - text mutations of the shared live regions, which is what a screen reader actually reacts
 *   to. A live region speaks on a text CHANGE, so a message identical to the one already
 *   showing produces no mutation and no entry here — that silence is the evidence, not a gap
 *   in the probe.
 *
 * It watches the whole document, so it reports on whichever control on the page has focus.
 */
export default class SelectAriaProbe extends Component {
  @service a11y;

  @tracked snapshot = null;

  entries = trackedArray();

  #observer = null;
  #observed = new WeakSet();
  #observedCount = 0;
  #seq = 0;

  constructor() {
    super(...arguments);

    document.addEventListener("focusin", this.capture, true);
    document.addEventListener("keyup", this.capture, true);
    document.addEventListener("click", this.capture, true);

    this.#observer = new MutationObserver(this.captureAnnouncements);
    // Deferred, and rescanned on every event afterwards. The shared regions render at the end of
    // the application template, after the subtree this component lives in, so on a cold load they
    // do not exist yet when this runs — and a modal-scoped region appears later still. A one-shot
    // scan in the constructor attaches to nothing and then reports silence indistinguishable from
    // a component that never announced.
    next(() => this.#attachRegions());

    registerDestructor(this, () => {
      document.removeEventListener("focusin", this.capture, true);
      document.removeEventListener("keyup", this.capture, true);
      document.removeEventListener("click", this.capture, true);
      this.#observer.disconnect();
    });
  }

  get visibleEntries() {
    return this.entries.slice(-VISIBLE_LIMIT).reverse();
  }

  @action
  capture(event) {
    // The probe's own controls are not part of the trace they produce.
    if (event.target?.closest?.(".select-aria-probe")) {
      return;
    }

    const label = event.type === "keyup" ? `keyup ${event.key}` : event.type;

    // After render: a key press moves the cursor during the render that follows it, so reading
    // synchronously reports the state before the move.
    next(() => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      this.#attachRegions();

      const snapshot = this.#read();
      this.snapshot = snapshot;
      this.#record(label, this.#summarize(snapshot), snapshot);
    });
  }

  @action
  captureAnnouncements(mutations) {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    for (const mutation of mutations) {
      // A text-node target has no `closest`, and rewriting a curly's text is the common case.
      const element =
        mutation.target.nodeType === Node.ELEMENT_NODE
          ? mutation.target
          : mutation.target.parentElement;
      const region = element?.closest("[aria-live]") ?? element;
      const politeness = region?.getAttribute("aria-live") ?? "?";
      const text = region?.textContent.trim() ?? "";

      this.#record(`announce ${politeness}`, text ? `"${text}"` : "(cleared)", {
        text,
      });
    }
  }

  @action
  async copy() {
    const lines = this.entries.map((e) => `#${e.seq} ${e.label} ${e.detail}`);
    await navigator.clipboard.writeText(lines.join("\n"));
  }

  @action
  clear() {
    this.entries.splice(0, this.entries.length);
    this.snapshot = null;
  }

  /**
   * Pushes a known message through the shared announcement channel. An empty trace means either
   * that nothing announced or that this probe never attached to the region carrying it; this
   * tells the two apart without leaving the page.
   */
  @action
  testChannel() {
    this.a11y.announce("probe channel check", "polite");
  }

  #read() {
    const focused = document.activeElement;
    const activeId = focused?.getAttribute?.("aria-activedescendant");
    const target = activeId ? document.getElementById(activeId) : null;
    const listbox =
      target?.closest("[role=listbox]") ??
      document.querySelector("[role=listbox]");
    // The visual cursor. Where it and aria-activedescendant disagree, the two are separate
    // pieces of state that have drifted, which no attribute inspected on its own reveals.
    const highlighted = document.querySelector(".d-combobox__option.--active");

    return {
      focused: describeElement(focused),
      focusedLabel: focused?.getAttribute?.("aria-label") ?? "—",
      expanded: focused?.getAttribute?.("aria-expanded") ?? "—",
      activeId: activeId || (activeId === "" ? "(empty)" : "—"),
      resolves: activeId ? (target ? "yes" : "NO — dangling") : "—",
      rowText: describeRow(target),
      rowSelected: target?.getAttribute("aria-selected") ?? "—",
      rowPosition: target
        ? `${target.getAttribute("aria-posinset") ?? "?"} / ${
            target.getAttribute("aria-setsize") ?? "?"
          }`
        : "—",
      highlighted: describeRow(highlighted),
      cursorsAgree:
        highlighted || target
          ? highlighted === target
            ? "yes"
            : "NO — visual and ARIA cursors differ"
          : "—",
      // Everything between the option and the document. A cursor can resolve perfectly and still
      // go unread because something on the way up removes the row from the accessibility tree,
      // or because the combobox never claims containment of the subtree it points into — neither
      // of which is visible on the option or the controller alone.
      barriers: describeBarriers(target),
      owns: focused?.getAttribute?.("aria-owns") ?? "—",
      containment: describeContainment(focused, target),
      multiselectable: listbox?.getAttribute("aria-multiselectable") ?? "—",
      rowCount: listbox
        ? String(listbox.querySelectorAll("[role=option]").length)
        : "—",
      selectedInList: listbox
        ? String(listbox.querySelectorAll("[aria-selected='true']").length)
        : "—",
    };
  }

  /**
   * A one-line form of the snapshot, with unset fields omitted. Long traces are read by being
   * pasted somewhere else, and a line of placeholder dashes costs the reader attention and the
   * paste a length limit without carrying anything.
   */
  #summarize(snapshot) {
    return [
      `focus=${snapshot.focused}`,
      `expanded=${snapshot.expanded}`,
      `ad=${snapshot.activeId}`,
      `resolves=${snapshot.resolves}`,
      `barriers=${snapshot.barriers}`,
      `containment=${snapshot.containment}`,
      `row=${snapshot.rowText}`,
      `selected=${snapshot.rowSelected}`,
      `visual=${snapshot.highlighted}`,
      `agree=${snapshot.cursorsAgree}`,
    ]
      .filter((pair) => !pair.endsWith("=—"))
      .join(" ");
  }

  #attachRegions() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    const regions = document.querySelectorAll("[aria-live]");
    let added = 0;

    for (const region of regions) {
      if (this.#observed.has(region)) {
        continue;
      }
      this.#observed.add(region);
      added += 1;
      this.#observer.observe(region, {
        childList: true,
        characterData: true,
        subtree: true,
      });
    }

    if (added) {
      this.#observedCount += added;
      this.#record(
        "probe",
        `watching ${this.#observedCount} live region(s)`,
        null
      );
    }
  }

  #record(label, detail, payload) {
    this.#seq += 1;
    const entry = { seq: this.#seq, label, detail };

    this.entries.push(entry);
    if (this.entries.length > HISTORY_LIMIT) {
      this.entries.splice(0, this.entries.length - HISTORY_LIMIT);
    }

    // eslint-disable-next-line no-console
    console.log(`[aria] #${entry.seq} ${label} ${detail}`, payload);
  }

  <template>
    <div class="select-aria-probe">
      <p class="select-aria-probe__title">
        {{i18n "styleguide.sections.select.aria_probe_title"}}
      </p>
      <p class="select-aria-probe__hint">
        {{i18n "styleguide.sections.select.aria_probe_description"}}
      </p>

      <div class="select-aria-probe__actions">
        <DButton
          class="btn-small"
          @action={{this.copy}}
          @label="styleguide.sections.select.aria_probe_copy"
        />
        <DButton
          class="btn-small btn-flat"
          @action={{this.testChannel}}
          @label="styleguide.sections.select.aria_probe_test_channel"
        />
        <DButton
          class="btn-small btn-flat"
          @action={{this.clear}}
          @label="styleguide.sections.select.aria_probe_clear"
        />
      </div>

      {{#if this.snapshot}}
        <dl class="select-aria-probe__rows">
          <dt>focus</dt>
          <dd>{{this.snapshot.focused}}</dd>
          <dt>aria-label</dt>
          <dd>{{this.snapshot.focusedLabel}}</dd>
          <dt>aria-expanded</dt>
          <dd>{{this.snapshot.expanded}}</dd>
          <dt>aria-activedescendant</dt>
          <dd>{{this.snapshot.activeId}}</dd>
          <dt>resolves</dt>
          <dd>{{this.snapshot.resolves}}</dd>
          <dt>row</dt>
          <dd>{{this.snapshot.rowText}}</dd>
          <dt>aria-selected</dt>
          <dd>{{this.snapshot.rowSelected}}</dd>
          <dt>position</dt>
          <dd>{{this.snapshot.rowPosition}}</dd>
          <dt>visual cursor</dt>
          <dd>{{this.snapshot.highlighted}}</dd>
          <dt>cursors agree</dt>
          <dd>{{this.snapshot.cursorsAgree}}</dd>
          <dt>barriers</dt>
          <dd>{{this.snapshot.barriers}}</dd>
          <dt>aria-owns</dt>
          <dd>{{this.snapshot.owns}}</dd>
          <dt>containment</dt>
          <dd>{{this.snapshot.containment}}</dd>
          <dt>aria-multiselectable</dt>
          <dd>{{this.snapshot.multiselectable}}</dd>
          <dt>rows in list</dt>
          <dd>{{this.snapshot.rowCount}}</dd>
          <dt>selected rows in list</dt>
          <dd>{{this.snapshot.selectedInList}}</dd>
        </dl>
      {{/if}}

      {{#if this.entries.length}}
        <ol class="select-aria-probe__timeline">
          {{#each this.visibleEntries key="seq" as |entry|}}
            <li>
              <span class="select-aria-probe__seq">#{{entry.seq}}</span>
              <span class="select-aria-probe__label">{{entry.label}}</span>
              <span class="select-aria-probe__detail">{{entry.detail}}</span>
            </li>
          {{/each}}
        </ol>
      {{/if}}
    </div>
  </template>
}
