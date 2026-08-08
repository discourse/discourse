import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import type User from "discourse/models/user";
import type ModalService from "discourse/services/modal";
import type SiteSettingsService from "discourse/services/site-settings";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import PagePickerModal from "discourse/plugins/discourse-wireframe/discourse/components/editor/simulation/page-picker-modal";

type WireframeButtonSignature = {
  /** Connector arguments supplied by the admin theme page. */
  Args: {
    /** Arguments owned by the surrounding plugin outlet. */
    outletArgs: {
      /** Theme currently open in the admin UI. */
      theme: {
        /** Numeric theme identifier. */
        id: number;
        /** Human-readable theme name. */
        name: string;
      };
    };
  };
};

type WireframeSiteSettingsService = SiteSettingsService & {
  /** Whether the wireframe editor is enabled. */
  wireframe_enabled: boolean;
};

type AdminCurrentUser = User & {
  /** Whether the current user is an administrator. */
  admin?: boolean;
};

type ShouldRenderContext = {
  /** Signed-in user, or `null` for an anonymous visitor. */
  currentUser: AdminCurrentUser | null;
  /** Client site settings plus the plugin setting used by this connector. */
  siteSettings: WireframeSiteSettingsService;
};

// TODO(devxp-typescript-pending): replace the local outlet-args shape once the
// admin theme controls outlet exports its connector argument contract.
// TODO(devxp-typescript-pending): replace `WireframeSiteSettingsService` once
// core exposes an extendable client site-settings registry for plugin settings.
// TODO(devxp-typescript-pending): remove `AdminCurrentUser` once core's `User`
// type declares the runtime `admin` flag used by connector contexts.

/**
 * Adds a "Wireframe" button next to the existing theme-show controls
 * (Preview / Export / Import). Clicking opens a modal that lets the admin
 * pick which page to land on; the modal navigates to that page with
 * `?wf_theme=<theme-id>` so the in-context pill auto-enters editor mode
 * bound to this theme.
 *
 * Hidden when:
 *   - the user isn't an admin (PluginOutlets render nothing for non-admins
 *     here anyway, but defense in depth),
 *   - the `wireframe_enabled` site setting is off.
 */
export default class WireframeButton extends Component<WireframeButtonSignature> {
  /**
   * Checks whether the connector should render for this session.
   *
   * @param _args - Connector arguments, unused by the visibility check.
   * @param context - Current user and client site settings.
   * @returns Whether the wireframe launch button should render.
   */
  static shouldRender(
    _args: WireframeButtonSignature["Args"],
    { currentUser, siteSettings }: ShouldRenderContext
  ): boolean {
    if (!currentUser?.admin) {
      return false;
    }
    if (!siteSettings.wireframe_enabled) {
      return false;
    }
    return true;
  }

  /** Opens the page-picker modal. */
  @service declare modal: ModalService;

  /** Whether a modal-open operation is in flight. */
  @tracked isOpening = false;

  /**
   * Opens the page-picker modal so the admin can choose which page to
   * launch the wireframe editor on. The modal is responsible for the
   * eventual navigation; this action only flips the loading flag.
   */
  @action
  async openPagePicker(): Promise<void> {
    this.isOpening = true;
    try {
      await this.modal.show(PagePickerModal, {
        model: { theme: this.args.outletArgs.theme },
      });
    } finally {
      this.isOpening = false;
    }
  }

  <template>
    <DButton
      class="btn-default wireframe-open-button"
      @icon="wand-magic-sparkles"
      @action={{this.openPagePicker}}
      @disabled={{this.isOpening}}
      @label="wireframe.theme_admin.open_button"
      @title="wireframe.theme_admin.open_button_title"
    />
    <span class="sr-only">{{i18n "wireframe.theme_admin.open_button"}}</span>
  </template>
}
