// @ts-check
import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

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
const TARGET_PAGES = [
  { key: "homepage", path: "/", labelKey: "homepage" },
  { key: "categories", path: "/categories", labelKey: "categories" },
  { key: "latest", path: "/latest", labelKey: "latest" },
];

export default class PagePickerModal extends Component {
  get theme() {
    return this.args.model?.theme;
  }

  /**
   * Builds the URL we navigate to when a page is picked. The destination
   * gets a `wf_theme=<id>` query param so the in-context entry pill enters
   * editor mode against the right theme on arrival.
   */
  @action
  navigate(page) {
    if (!this.theme?.id) {
      return;
    }
    this.args.closeModal();
    const url = `${page.path}?wf_theme=${this.theme.id}`;
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
