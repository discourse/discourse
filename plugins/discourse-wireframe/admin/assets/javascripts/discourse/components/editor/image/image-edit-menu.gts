import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import type WireframeImageUploadService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-image-upload";

export type ImageEditMenuData = {
  /** Composite key of the block whose image is being edited. */
  blockKey: string;
  /** Name of the image argument being edited. */
  argName: string;
  /** Closes the owning FloatKit menu. */
  close: () => void;
};

interface ImageEditMenuSignature {
  /** FloatKit data identifying the editable image argument. */
  Args: {
    /** Block, argument, and menu-close data. */
    data: ImageEditMenuData;
  };
}

/**
 * FloatKit menu content for editing a filled image arg. Mounted via
 * `menu.show(triggerEl, { component: ImageEditMenu, data: ... })` from
 * `block-chrome.gts` when the user clicks the rendered `<img>` /
 * `<picture>` / backdrop marker of a filled image arg.
 *
 * @data shape (injected by FloatKit, available as `@data` on this
 * component):
 *   - blockKey {string}     The block whose arg is being edited.
 *   - argName  {string}     The image arg name.
 *   - close    {() => void} Closes the menu (provided by FloatKit's
 *                           per-instance options).
 */
export default class ImageEditMenu extends Component<ImageEditMenuSignature> {
  /** Uploads and writes image argument values. */
  @service declare wireframeImageUpload: WireframeImageUploadService;

  /**
   * Hidden file input ref used by the Replace action. Triggered
   * programmatically from `replace()`; the input lives inside the
   * menu so its lifetime matches the menu's open state.
   *
   */
  #fileInputEl: HTMLInputElement | null = null;

  /**
   * Stores the hidden replacement file input.
   *
   * @param element - Mounted image file input.
   */
  @action
  registerFileInput(element: HTMLInputElement): void {
    this.#fileInputEl = element;
  }

  /** Opens the replacement file chooser. */
  @action
  replace(): void {
    this.#fileInputEl?.click();
  }

  /**
   * Uploads the selected replacement image.
   *
   * @param event - Image file-input change event.
   */
  @action
  async onFileChosen(event: Event): Promise<void> {
    if (!(event.currentTarget instanceof HTMLInputElement)) {
      return;
    }
    const input = event.currentTarget;
    const file = input.files?.[0];
    if (!file) {
      return;
    }
    input.value = "";

    await this.wireframeImageUpload.uploadImageForArg(file, {
      blockKey: this.args.data.blockKey,
      argName: this.args.data.argName,
    });
    this.args.data.close();
  }

  /** Clears the image argument and closes the menu. */
  @action
  remove(): void {
    this.wireframeImageUpload.setImageArg(
      this.args.data.blockKey,
      this.args.data.argName,
      null
    );
    this.args.data.close();
  }

  <template>
    <ul class="wireframe-image-edit-menu">
      <li>
        <button
          type="button"
          class="btn btn-flat wireframe-image-edit-menu__item"
          {{on "click" this.replace}}
        >
          {{dIcon "arrows-rotate"}}
          {{i18n "wireframe.canvas.image_menu_replace"}}
        </button>
      </li>
      <li>
        <button
          type="button"
          class="btn btn-flat wireframe-image-edit-menu__item wireframe-image-edit-menu__item--danger"
          {{on "click" this.remove}}
        >
          {{dIcon "trash-can"}}
          {{i18n "wireframe.canvas.image_menu_remove"}}
        </button>
      </li>
    </ul>
    <input
      type="file"
      accept="image/*"
      hidden
      {{on "change" this.onFileChosen}}
      {{didInsert this.registerFileInput}}
    />
  </template>
}
