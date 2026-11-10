import Service, { service } from "@ember/service";
import { MAIN_PANEL } from "discourse/lib/sidebar/panels";

export const STYLEGUIDE_PANEL = "styleguide";

/**
 * Hands the main sidebar over to the styleguide's own navigation while the user is inside the
 * styleguide, and gives it back on the way out.
 *
 * The styleguide used to render a second nav column of its own beside Discourse's, which cost a
 * third of the viewport and showed forum navigation nobody needs while reading component docs.
 * Taking over the one sidebar is the same trade the admin area and the docs plugin already make.
 */
export default class StyleguideSidebarService extends Service {
  @service sidebarState;

  /** Whether the styleguide panel is still the one on screen. */
  get #isVisible() {
    return this.sidebarState.currentPanel?.key === STYLEGUIDE_PANEL;
  }

  showSidebar() {
    // Order matters: `setSeparatedMode` turns the switch buttons back on, so hiding them has to
    // come after it, and both have to come after the panel is current.
    this.sidebarState.setPanel(STYLEGUIDE_PANEL);
    this.sidebarState.setSeparatedMode();
    this.sidebarState.hideSwitchPanelButtons();

    // Renders the sidebar even for a reader whose navigation preference is the header dropdown.
    // The styleguide's nav was unconditional before this, so losing it on a preference would be
    // a regression rather than that preference being honored.
    this.sidebarState.isForcingSidebar = true;
    this.sidebarState.forcingSidebarPanel = STYLEGUIDE_PANEL;
  }

  hideSidebar() {
    // Only unwind what this service actually set. Another feature may have taken the sidebar
    // during the same transition, and clearing its claim would strand it.
    if (this.sidebarState.forcingSidebarPanel !== STYLEGUIDE_PANEL) {
      return;
    }

    if (this.#isVisible) {
      this.sidebarState.setPanel(MAIN_PANEL);
    }

    this.sidebarState.isForcingSidebar = false;
    this.sidebarState.forcingSidebarPanel = null;
  }
}
