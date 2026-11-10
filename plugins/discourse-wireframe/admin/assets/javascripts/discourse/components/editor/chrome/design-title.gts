import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import type RouterService from "@ember/routing/router-service";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import type DialogService from "discourse/dialog-holder/services/dialog";
import DMenu from "discourse/float-kit/components/d-menu";
import type DMenuInstance from "discourse/float-kit/lib/d-menu-instance";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";
import WireframeDraftsService, {
  Design,
} from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-drafts";
import type WireframeMutationEngineService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-mutation-engine";
import type WireframePublishTargetService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-publish-target";
import type WireframeStagingService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-staging";
import type WireframeWorkspaceService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-workspace";

/**
 * The toolbar is fixed chrome above the site header, so the menu doesn't need
 * to clear it the way floats elsewhere on the page do.
 */
const MENU_PADDING = { top: 8, right: 10, bottom: 10, left: 10 };

/** Sizes an input to its text, so the title reads as text until it's edited. */
const autosize = modifier((element: HTMLInputElement) => {
  const sync = () =>
    element.style.setProperty(
      "--title-length",
      String(Math.max(element.value.length, 1) + 1)
    );
  sync();
  Promise.resolve().then(() => {
    element.focus();
    element.select();
  });
  element.addEventListener("input", sync);
  return () => element.removeEventListener("input", sync);
});

/**
 * The design's name in the toolbar header, editable in place like a theme or
 * topic title, with a menu to switch to another design or start a new one. Until
 * the first publish the name is a placeholder the author can already change; it
 * is used when the design is created. A design is a theme component behind the
 * scenes, but nothing here says so.
 */
export default class DesignTitle extends Component {
  /** Reports rename and switch failures. */
  @service declare dialog: DialogService;

  /** Opens the admin designs list. */
  @service declare router: RouterService;

  /** Lists the theme's designs. */
  @service declare wireframeDrafts: WireframeDraftsService;

  /** Tells whether unsaved edits exist. */
  @service declare wireframeMutationEngine: WireframeMutationEngineService;

  /** Resolves the active design. */
  @service declare wireframePublishTarget: WireframePublishTargetService;

  /** Creates, renames and installs designs. */
  @service declare wireframeStaging: WireframeStagingService;

  /** Leaves the editor before opening the designs list. */
  @service declare wireframeWorkspace: WireframeWorkspaceService;

  /** Whether the title is being edited. */
  @tracked isEditing = false;

  /** The in-progress title text. */
  @tracked editValue = "";

  /** Designs of the theme in use, refreshed each time the menu opens. */
  @tracked designs: Design[] = [];

  /** The open menu, so a pick can close it. */
  #menu: DMenuInstance | null = null;

  /** Whether there's a destination to name. */
  get available(): boolean {
    return this.wireframePublishTarget.activeThemeTarget != null;
  }

  @action
  startEditing(): void {
    this.editValue = this.wireframePublishTarget.designName;
    this.isEditing = true;
  }

  @action
  cancel(): void {
    this.isEditing = false;
  }

  @action
  onInput(event: Event): void {
    this.editValue = (event.target as HTMLInputElement).value;
  }

  @action
  async save(): Promise<void> {
    if (!this.isEditing) {
      return;
    }
    this.isEditing = false;
    const name = this.editValue.trim();
    if (!name || name === this.wireframePublishTarget.designName) {
      return;
    }
    const error = await this.wireframeStaging.renameDesign(name);
    if (error) {
      this.dialog.alert(error);
    }
  }

  @action
  handleKeydown(event: KeyboardEvent): void {
    if (event.key === "Enter") {
      this.save();
    } else if (event.key === "Escape") {
      this.cancel();
    }
  }

  @action
  registerMenu(menu: DMenuInstance): void {
    this.#menu = menu;
  }

  @action
  async loadDesigns(): Promise<void> {
    const parentId = this.wireframePublishTarget.parentThemeId;
    if (parentId == null) {
      return;
    }
    this.designs = (await this.wireframeDrafts.fetchDesigns(parentId)).designs;
  }

  @action
  pickDesign(designId: number): void {
    this.#menu?.close();
    if (designId === this.wireframePublishTarget.activeThemeId) {
      return;
    }
    const run = async () => {
      const error = await this.wireframeStaging.switchDesign(designId);
      if (error) {
        this.dialog.alert(error);
        return;
      }
      this.wireframePublishTarget.navigateToEditTheme(designId, {
        isComponent: true,
      });
    };
    this.#confirmDiscard(run);
  }

  @action
  async newDesign(): Promise<void> {
    this.#menu?.close();
    const { themeId, error } = await this.wireframeStaging.createDesign(
      i18n("wireframe.design.untitled"),
      { withEdits: true }
    );
    if (themeId) {
      this.wireframePublishTarget.navigateToEditTheme(themeId, {
        isComponent: true,
      });
    } else if (error) {
      this.dialog.alert(error);
    }
  }

  @action
  manageDesigns(): void {
    this.#menu?.close();
    this.#confirmDiscard(
      () => {
        this.wireframeWorkspace.exit();
        this.router.transitionTo(
          "adminPlugins.show.wireframe-designs",
          "discourse-wireframe"
        );
      },
      {
        message: "wireframe.design.leave_discard_confirm",
        button: "wireframe.design.leave_discard_button",
      }
    );
  }

  /**
   * Switching designs or leaving the editor discards unsaved edits, so they
   * need an explicit go-ahead.
   *
   * @param proceed - Runs once the author has agreed to continue.
   * @param keys - Translation keys for the prompt.
   *   - `message` - The confirmation message.
   *   - `button` - The confirm button label.
   */
  #confirmDiscard(
    proceed: () => void,
    {
      message = "wireframe.design.switch_discard_confirm",
      button = "wireframe.design.switch_discard_button",
    }: {
      /** Translation key for the confirmation message. */
      message?: string;
      /** Translation key for the confirm button label. */
      button?: string;
    } = {}
  ): void {
    if (!this.wireframeMutationEngine.isDirty) {
      proceed();
      return;
    }
    this.dialog.confirm({
      message: i18n(message),
      confirmButtonLabel: button,
      didConfirm: proceed,
    });
  }

  <template>
    {{#if this.available}}
      <div class="wireframe-design-title wireframe-target-indicator">
        {{#if this.isEditing}}
          <input
            aria-label={{i18n "wireframe.design.name_label"}}
            class="wireframe-design-title__input"
            type="text"
            value={{this.editValue}}
            {{autosize}}
            {{on "input" this.onInput}}
            {{on "keydown" this.handleKeydown}}
            {{on "blur" this.save}}
          />
        {{else}}
          <button
            class="wireframe-design-title__text"
            title={{i18n "wireframe.design.rename"}}
            type="button"
            {{on "click" this.startEditing}}
          >{{this.wireframePublishTarget.designName}}</button>
        {{/if}}
        <DMenu
          @icon="chevron-down"
          @identifier="wireframe-design-switcher"
          @onRegisterApi={{this.registerMenu}}
          @onShow={{this.loadDesigns}}
          @padding={{MENU_PADDING}}
          @title={{i18n "wireframe.design.switch"}}
          @triggerClass="btn-flat btn-small wireframe-design-title__menu"
        >
          <:content>
            <div class="wireframe-design-switcher">
              <DDropdownMenu as |dropdown|>
                {{#each this.designs as |design|}}
                  <dropdown.item>
                    <DButton
                      class="btn-transparent wireframe-design-switcher__design"
                      @action={{fn this.pickDesign design.id}}
                      @icon={{if design.active "check"}}
                      @translatedLabel={{design.name}}
                    />
                  </dropdown.item>
                {{/each}}
                {{#if this.designs.length}}<dropdown.divider />{{/if}}
                <dropdown.item>
                  <DButton
                    class="btn-transparent wireframe-design-switcher__new"
                    @action={{this.newDesign}}
                    @icon="plus"
                    @label="wireframe.design.new"
                  />
                </dropdown.item>
                <dropdown.item>
                  <DButton
                    class="btn-transparent wireframe-design-switcher__manage"
                    @action={{this.manageDesigns}}
                    @icon="gear"
                    @label="wireframe.design.manage"
                  />
                </dropdown.item>
              </DDropdownMenu>
            </div>
          </:content>
        </DMenu>
      </div>
    {{/if}}
  </template>
}
