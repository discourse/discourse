// @ts-check
import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { buildSimulatedViewport } from "discourse/blocks/conditions/viewport";
import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
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

const VIEWPORTS = Object.freeze({
  real: null,
  mobile: { breakpoint: "sm", touch: true },
  tablet: { breakpoint: "md", touch: true },
  desktop: { breakpoint: "xl", touch: false },
});

/**
 * Persona + viewport simulation toolbar controls for Phase 7. Both
 * dropdowns thread their picked value into the simulation service's
 * slot; that flows through to the condition evaluator's context via the
 * `EVAL_CONTEXT` debug hook (`api-initializer: installSimulationContext`).
 *
 * Block bodies themselves still render with the real user's data — see
 * the inline disclosure tooltip on the indicator. This is the
 * "condition-only" simulation scope; full preview ships in a later
 * phase.
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
    // Find the smallest matching breakpoint.
    const bp = ["sm", "md", "lg", "xl", "2xl"].find(
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

  @action
  handlePersonaChange(event) {
    const key = event.target.value;
    if (key === "real") {
      this.wireframeSimulation.setUser(undefined);
      return;
    }
    // PERSONAS["anonymous"] is `null` (explicit anonymous sentinel); the
    // rest map to user-shaped objects. Either way, this sets the slot
    // explicitly so `"user" in simulation` becomes true.
    this.wireframeSimulation.setUser(PERSONAS[key]);
  }

  @action
  handleViewportChange(event) {
    const key = event.target.value;
    if (key === "real") {
      this.wireframeSimulation.setViewport(undefined);
      return;
    }
    const pick = VIEWPORTS[key];
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
    <div
      class={{dConcatClass
        "wireframe-simulation"
        (if this.wireframeSimulation.isSimulating "--active")
      }}
    >
      <select
        class="wireframe-simulation__persona"
        aria-label={{i18n "wireframe.chrome.simulation.persona_label"}}
        title={{i18n "wireframe.chrome.simulation.persona_label"}}
        {{on "change" this.handlePersonaChange}}
      >
        <option value="real" selected={{eq this.currentPersona "real"}}>
          {{i18n "wireframe.chrome.simulation.persona_real"}}
        </option>
        <option
          value="anonymous"
          selected={{eq this.currentPersona "anonymous"}}
        >
          {{i18n "wireframe.chrome.simulation.persona_anonymous"}}
        </option>
        <option value="tl0" selected={{eq this.currentPersona "tl0"}}>
          {{i18n "wireframe.chrome.simulation.persona_tl0"}}
        </option>
        <option value="tl1" selected={{eq this.currentPersona "tl1"}}>
          {{i18n "wireframe.chrome.simulation.persona_tl1"}}
        </option>
        <option value="tl2" selected={{eq this.currentPersona "tl2"}}>
          {{i18n "wireframe.chrome.simulation.persona_tl2"}}
        </option>
        <option value="tl3" selected={{eq this.currentPersona "tl3"}}>
          {{i18n "wireframe.chrome.simulation.persona_tl3"}}
        </option>
        <option value="tl4" selected={{eq this.currentPersona "tl4"}}>
          {{i18n "wireframe.chrome.simulation.persona_tl4"}}
        </option>
        <option value="admin" selected={{eq this.currentPersona "admin"}}>
          {{i18n "wireframe.chrome.simulation.persona_admin"}}
        </option>
      </select>

      <select
        class="wireframe-simulation__viewport"
        aria-label={{i18n "wireframe.chrome.simulation.viewport_label"}}
        title={{i18n "wireframe.chrome.simulation.viewport_label"}}
        {{on "change" this.handleViewportChange}}
      >
        <option value="real" selected={{eq this.currentViewport "real"}}>
          {{i18n "wireframe.chrome.simulation.viewport_real"}}
        </option>
        <option value="mobile" selected={{eq this.currentViewport "mobile"}}>
          {{i18n "wireframe.chrome.simulation.viewport_mobile"}}
        </option>
        <option value="tablet" selected={{eq this.currentViewport "tablet"}}>
          {{i18n "wireframe.chrome.simulation.viewport_tablet"}}
        </option>
        <option value="desktop" selected={{eq this.currentViewport "desktop"}}>
          {{i18n "wireframe.chrome.simulation.viewport_desktop"}}
        </option>
      </select>

      {{#if this.wireframeSimulation.isSimulating}}
        <span
          class="wireframe-simulation__dot"
          role="status"
          title={{i18n "wireframe.chrome.simulation.disclosure_tooltip"}}
        >
          {{dIcon "circle"}}
        </span>
      {{/if}}
    </div>
  </template>
}
