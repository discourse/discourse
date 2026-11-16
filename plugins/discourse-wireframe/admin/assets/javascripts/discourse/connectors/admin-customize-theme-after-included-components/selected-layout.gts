import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import type User from "discourse/models/user";
import type SiteSettingsService from "discourse/services/site-settings";
import DNativeSelect from "discourse/ui-kit/d-native-select";
import { i18n } from "discourse-i18n";

const COMPANION_URL = "/admin/plugins/wireframe/companion.json";

type Design = {
  /** Theme id of the design component. */
  id: number;
  /** Design name. */
  name: string;
  /** Whether the design is currently installed on the theme. */
  active: boolean;
};

type SelectedLayoutSignature = {
  Args: {
    outletArgs: {
      /** Theme currently open in the admin UI. */
      theme: { id: number };
    };
  };
};

// TODO(devxp-typescript-pending): replace the loose context types once core
// exports typed connector contexts and plugin site settings.
type ShouldRenderContext = {
  currentUser: (User & { admin?: boolean }) | null;
  siteSettings: SiteSettingsService & { wireframe_enabled?: boolean };
};

/**
 * Lets an admin pick which layout design is applied to a theme. Designs are
 * theme components under the hood, but they are managed here rather than in the
 * "included components" input, and at most one can be selected.
 */
export default class SelectedLayout extends Component<SelectedLayoutSignature> {
  static shouldRender(
    _args: SelectedLayoutSignature["Args"],
    { currentUser, siteSettings }: ShouldRenderContext
  ): boolean {
    return !!currentUser?.admin && !!siteSettings.wireframe_enabled;
  }

  @tracked designs: Design[] = [];
  @tracked selectedId: number | null = null;

  constructor(owner: unknown, args: SelectedLayoutSignature["Args"]) {
    super(owner as never, args);
    this.#load();
  }

  get themeId(): number {
    return this.args.outletArgs.theme.id;
  }

  @action
  async select(value: string | null): Promise<void> {
    const previous = this.selectedId;
    this.selectedId = value ? Number(value) : null;
    try {
      await ajax(COMPANION_URL, {
        type: "PUT",
        data: { theme_id: this.themeId, design_id: value ?? "" },
      });
    } catch (error) {
      this.selectedId = previous;
      popupAjaxError(error);
    }
  }

  async #load(): Promise<void> {
    try {
      const response = (await ajax(COMPANION_URL, {
        data: { theme_id: this.themeId },
      })) as { companion_id: number | null; designs: Design[] };
      this.designs = response.designs;
      this.selectedId = response.companion_id;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    {{#if this.designs.length}}
      <section
        class="form-horizontal theme settings control-unit selected-layout"
      >
        <div class="row setting">
          <div class="setting-label">
            <h3>{{i18n "wireframe.theme_admin.selected_layout"}}</h3>
          </div>
          <div class="setting-value">
            <DNativeSelect
              @includeNone={{true}}
              @nonePlaceholder={{i18n
                "wireframe.theme_admin.selected_layout_none"
              }}
              @onChange={{this.select}}
              @value={{this.selectedId}}
              as |select|
            >
              {{#each this.designs as |design|}}
                <select.Option
                  @value={{design.id}}
                >{{design.name}}</select.Option>
              {{/each}}
            </DNativeSelect>
            <div class="desc">{{i18n
                "wireframe.theme_admin.selected_layout_help"
              }}</div>
          </div>
        </div>
      </section>
    {{/if}}
  </template>
}
