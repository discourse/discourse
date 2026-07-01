// @ts-check
import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { buildSimulatedViewport } from "discourse/blocks/conditions/viewport";
import DSegmentedControl from "discourse/components/d-segmented-control";
import FKAlert from "discourse/form-kit/components/fk/alert";
import DropdownSelectBox from "discourse/select-kit/components/dropdown-select-box";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

/**
 * Map of persona keys → the simulated user payload the `user` condition
 * reads from `context.simulation.user`. `null` is the explicit anonymous
 * sentinel; the absence of the persona slot on the simulation object
 * means "use the real currentUser".
 *
 * Trust levels carry through `staff: false` / `admin: false` flags
 * explicitly so condition checks like `staff: true` against a TL3
 * simulated user resolve to `false` rather than `undefined`.
 */
const PERSONAS = Object.freeze({
  anonymous: null,
  tl0: { trust_level: 0, staff: false, admin: false, moderator: false },
  tl1: { trust_level: 1, staff: false, admin: false, moderator: false },
  tl2: { trust_level: 2, staff: false, admin: false, moderator: false },
  tl3: { trust_level: 3, staff: false, admin: false, moderator: false },
  tl4: { trust_level: 4, staff: false, admin: false, moderator: false },
  admin: { trust_level: 4, staff: true, admin: true, moderator: true },
});

/**
 * Persona option keys in display order. `real` (the un-simulated default) leads,
 * then the ascending trust levels bracketed by the anonymous and admin extremes.
 */
const PERSONA_ORDER = [
  "real",
  "anonymous",
  "tl0",
  "tl1",
  "tl2",
  "tl3",
  "tl4",
  "admin",
];

/**
 * Per-persona icon for the rich dropdown rows. FontAwesome ids matching core's
 * user conventions: `user-xmark` for a logged-out visitor and `shield-halved`
 * for staff (as in the group-member controls). Trust levels share the plain
 * `user` glyph (their name + description carry the distinction); the real
 * account uses `circle-user` to set it apart.
 *
 * @type {Record<string, string>}
 */
const PERSONA_ICONS = {
  real: "circle-user",
  anonymous: "user-xmark",
  tl0: "user",
  tl1: "user",
  tl2: "user",
  tl3: "user",
  tl4: "user",
  admin: "shield-halved",
};

const VIEWPORTS = Object.freeze({
  real: null,
  mobile: { breakpoint: "sm", touch: true },
  tablet: { breakpoint: "md", touch: true },
  desktop: { breakpoint: "xl", touch: false },
});

/**
 * Viewport segments, largest-to-smallest after the un-simulated default.
 * FontAwesome device glyphs (the Lucide tablet/phone read too alike);
 * `real` stays a short text label since no device glyph fits it.
 */
const VIEWPORT_ITEMS = [
  { value: "real" },
  { value: "desktop", icon: "desktop" },
  { value: "tablet", icon: "tablet-screen-button" },
  { value: "mobile", icon: "mobile-screen-button" },
];

/**
 * Persona + viewport simulation controls, rendered inside the topbar's `View`
 * menu. Both pickers thread their value into the simulation service's slot; that
 * flows through to the condition evaluator's context via the `EVAL_CONTEXT` debug
 * hook (`api-initializer: installSimulationContext`).
 *
 * Block bodies themselves still render with the real user's data — this is the
 * "condition-only" simulation scope; full preview ships in a later phase.
 */
export default class SimulationControls extends Component {
  @service wireframeSimulation;

  get currentPersona() {
    const sim = this.wireframeSimulation.value;
    if (!sim || !("user" in sim)) {
      return "real";
    }
    if (sim.user === null) {
      return "anonymous";
    }
    if (sim.user.admin) {
      return "admin";
    }
    return `tl${sim.user.trust_level ?? 0}`;
  }

  get currentViewport() {
    const sim = this.wireframeSimulation.value;
    if (!sim || !("viewport" in sim) || !sim.viewport) {
      return "real";
    }
    // `buildSimulatedViewport` marks every breakpoint at-or-below the chosen
    // size `true` (the "viewport is at least this wide" semantics), so the
    // chosen size is the LARGEST breakpoint still true — scan from the top.
    const bp = ["2xl", "xl", "lg", "md", "sm"].find(
      (b) => sim.viewport.viewport?.[b] === true
    );
    if (bp === "sm") {
      return "mobile";
    }
    if (bp === "md") {
      return "tablet";
    }
    return "desktop";
  }

  /**
   * Persona picker rows for the rich dropdown: each key paired with its
   * translated name, a one-line description, and an icon. `id` / `name` match
   * the select-kit defaults so the row renders icon + name + description.
   *
   * @returns {Array<{id: string, name: string, description: string, icon: string}>}
   */
  @cached
  get personaOptions() {
    return PERSONA_ORDER.map((id) => ({
      id,
      name: i18n(`wireframe.chrome.simulation.persona_${id}`),
      description: i18n(
        `wireframe.chrome.simulation.persona_${id}_description`
      ),
      icon: PERSONA_ICONS[id],
    }));
  }

  /**
   * Viewport segments for the segmented control. Devices are icon-only with a
   * translated `title` (which doubles as the tooltip and the accessible name);
   * the un-simulated default carries a short visible label instead.
   *
   * @returns {Array<{value: string, icon?: string, label?: string, title: string}>}
   */
  @cached
  get viewportItems() {
    return VIEWPORT_ITEMS.map((item) => {
      const title = i18n(`wireframe.chrome.simulation.viewport_${item.value}`);
      return item.icon ? { ...item, title } : { ...item, label: title, title };
    });
  }

  @action
  handlePersonaChange(value) {
    if (value === "real") {
      this.wireframeSimulation.setUser(undefined);
      return;
    }
    // PERSONAS["anonymous"] is `null` (explicit anonymous sentinel); the rest
    // map to user-shaped objects. Either way, this sets the slot explicitly so
    // `"user" in simulation` becomes true.
    this.wireframeSimulation.setUser(PERSONAS[value]);
  }

  @action
  handleViewportChange(value) {
    const pick = VIEWPORTS[value];
    if (!pick) {
      this.wireframeSimulation.setViewport(undefined);
      return;
    }
    this.wireframeSimulation.setViewport(buildSimulatedViewport(pick));
  }

  @action
  clear() {
    this.wireframeSimulation.clear();
  }

  <template>
    <div class="wireframe-simulation">
      <h3 class="wireframe-simulation__title">
        {{i18n "wireframe.chrome.simulation.heading"}}
      </h3>

      {{! When a simulation is running, lead the section with a prominent status
          callout (matching the inspector's alert pattern) that also hosts the
          one-click reset; otherwise a short intro explains what simulating does. }}
      {{#if this.wireframeSimulation.isSimulating}}
        <FKAlert
          @type="info"
          @icon="wf-info"
          class="wireframe-simulation__status"
          role="note"
        >
          <span class="wireframe-simulation__status-text">
            <strong>{{i18n "wireframe.chrome.simulation.active_title"}}</strong>
            {{i18n "wireframe.chrome.simulation.active_body"}}
          </span>
          <DButton
            class="btn-default btn-small wireframe-simulation__clear"
            @icon="wf-rotate-ccw"
            @label="wireframe.chrome.simulation.clear"
            @action={{this.clear}}
          />
        </FKAlert>
      {{else}}
        <p class="wireframe-simulation__intro">
          {{i18n "wireframe.chrome.simulation.intro"}}
        </p>
      {{/if}}

      <div class="wireframe-simulation__field">
        <span class="wireframe-simulation__label">
          {{i18n "wireframe.chrome.simulation.persona_label"}}
        </span>
        <DropdownSelectBox
          class="wireframe-simulation__persona"
          @content={{this.personaOptions}}
          @value={{this.currentPersona}}
          @onChange={{this.handlePersonaChange}}
          @options={{hash showCaret=true}}
        />
      </div>

      <div class="wireframe-simulation__field">
        <span class="wireframe-simulation__label">
          {{i18n "wireframe.chrome.simulation.viewport_label"}}
        </span>
        <DSegmentedControl
          class="wireframe-simulation__viewport"
          @name="wireframe-viewport"
          @items={{this.viewportItems}}
          @value={{this.currentViewport}}
          @onSelect={{this.handleViewportChange}}
        />
      </div>

    </div>
  </template>
}
