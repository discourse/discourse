import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { type ComponentLike } from "@glint/template";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import DModalUntyped from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

// TODO(devxp-typescript-pending): drop once DModal is authored in .gts with a
// real Signature, then import it directly. Untyped .gjs today gives Glint no
// arg/block/attr types, so we describe just the surface this modal uses.
const DModal = DModalUntyped as unknown as ComponentLike<{
  /** Modal title and close action. */
  Args: {
    /** Pre-translated modal title. */
    title?: string;
    /** Closes the modal. */
    closeModal?: () => void;
  };
  /** Root modal element. */
  Element: HTMLDivElement;
  /** Blocks yielded by the modal. */
  Blocks: {
    /** Modal body content. */
    body: [];
  };
}>;

/** A single navigable destination shown in the page picker. */
type TargetPage = {
  /** Stable identifier for the row. */
  key: string;

  /** Path the editor navigates to when this page is picked. */
  path: string;

  /** Suffix appended to the `wireframe.page_picker.pages.` i18n key. */
  labelKey: string;
};

type TargetTheme = {
  /** Numeric theme identifier. */
  id: number;
  /** Human-readable theme name. */
  name: string;
};

interface PagePickerModalSignature {
  /** Page-picker model and modal lifecycle callback. */
  Args: {
    /** Modal payload carrying the theme the editor will bind to. */
    model?: {
      /** Theme selected on the originating admin page. */
      theme?: TargetTheme;
    };

    /** Closes the modal; supplied by the modal service. */
    closeModal: () => void;
  };
}

/**
 * Page-picker shown after clicking "Wireframe" on the admin theme show
 * page. Lists the routes the editor knows how to land on; selecting one
 * navigates to that route with `?wf_theme=<theme-id>`. The in-context entry
 * pill on the destination page reads that param on mount and enters editor
 * mode bound to the chosen theme.
 *
 * Phase 3f ships a small, fixed list — homepage / categories / latest. The
 * list is tightly scoped because the rest of the editor's page-coverage
 * story (parametric routes like `/u/:username`, `/t/:slug/:id`) is part of
 * Phase 7's polish.
 */
const TARGET_PAGES: TargetPage[] = [
  { key: "homepage", path: "/custom", labelKey: "homepage" },
  { key: "categories", path: "/categories", labelKey: "categories" },
  { key: "latest", path: "/latest", labelKey: "latest" },
];

export default class PagePickerModal extends Component<PagePickerModalSignature> {
  /** Theme selected on the originating admin page. */
  get theme(): TargetTheme | undefined {
    return this.args.model?.theme;
  }

  /**
   * Builds the URL we navigate to when a page is picked. `wf_theme=<id>` makes
   * the in-context entry pill enter editor mode bound to the chosen theme on
   * arrival, and `preview_theme_id=<id>` makes the page RENDER that theme —
   * without it, every rendered-theme read (site settings, layout preloads)
   * would keep describing the admin's own theme. The homepage entry targets
   * `/custom` directly because `/` only resolves there for themes that have
   * already opted in.
   */
  @action
  navigate(page: TargetPage): void {
    if (!this.theme?.id) {
      return;
    }
    this.args.closeModal();
    const params = new URLSearchParams({
      wf_theme: String(this.theme.id),
      preview_theme_id: String(this.theme.id),
    });
    this._assign(getURL(`${page.path}?${params}`));
  }

  /**
   * Performs the full-document navigation. A thin, stubbable seam mirroring
   * `WireframePublishTargetService#navigateToEditTheme`.
   *
   * @param url - Site-relative URL to load.
   */
  _assign(url: string): void {
    window.location.assign(url);
  }

  <template>
    <DModal
      @title={{i18n "wireframe.page_picker.title"}}
      @closeModal={{@closeModal}}
      class="wireframe-page-picker"
    >
      <:body>
        <p>
          {{i18n "wireframe.page_picker.description" theme=this.theme.name}}
        </p>
        <ul class="wireframe-page-list">
          {{#each TARGET_PAGES as |page|}}
            <li>
              <DButton
                class="btn-default"
                @label={{concat "wireframe.page_picker.pages." page.labelKey}}
                @action={{fn this.navigate page}}
              />
            </li>
          {{/each}}
        </ul>
      </:body>
    </DModal>
  </template>
}
