import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { isValidHex, normalizeHex } from "discourse/lib/color-transformations";
import DButton from "discourse/ui-kit/d-button";
import DColorInput from "discourse/ui-kit/d-color-input";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";
import { i18n } from "discourse-i18n";

const TOKEN_SEPARATOR = "|";
const INDEX_KEY = "@index";
const WHOLE_HEX = /^[0-9a-f]{6}$/i;

/** A color as it is stored: 6-digit lowercase hex without `#`, or `null` when it isn't one. */
function storedColor(value) {
  const bare = (value ?? "").replace(/^#/, "");
  return isValidHex(bare) ? normalizeHex(bare).toLowerCase() : null;
}

/** A color typed in full, so committing it can't cut the typing short. */
function wholeColor(value) {
  const bare = (value ?? "").replace(/^#/, "");
  return WHOLE_HEX.test(bare) ? bare.toLowerCase() : null;
}

function colorLabel(color) {
  return `#${color}`;
}

function rowLabel(index) {
  return i18n("admin.site_settings.color_list.color", { position: index + 1 });
}

/**
 * Edits a list of colors whose order matters, such as colors offered in order or assigned by position.
 * Each row is a color input; rows can be moved and removed, and a color is added at the end.
 * Colors are stored as 6-digit lowercase hex without `#`. `@onChange` receives the new list.
 */
export default class ColorList extends Component {
  /** What the add field holds, as typed. */
  @tracked draft = "";

  get addTitle() {
    if (this.draftHeld) {
      return i18n("admin.site_settings.color_list.already_listed");
    }
    return null;
  }

  get canAdd() {
    return !this.args.disabled && Boolean(this.draftColor) && !this.draftHeld;
  }

  /** The stored colors, in lowercase whatever case they were saved in, so any change saves them so. */
  get colors() {
    return (this.args.values ?? "")
      .toLowerCase()
      .split(TOKEN_SEPARATOR)
      .filter(Boolean);
  }

  get draftColor() {
    return storedColor(this.draft);
  }

  get draftHeld() {
    return Boolean(this.draftColor) && this.colors.includes(this.draftColor);
  }

  @action
  add() {
    if (!this.canAdd) {
      return;
    }
    this.args.onChange([...this.colors, this.draftColor]);
    this.draft = "";
  }

  @action
  addOnEnter(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      this.add();
    }
  }

  @action
  updateDraft(value) {
    this.draft = value;
  }

  /** Commits a row's color once it is typed in full or picked. */
  @action
  editColor(index, value) {
    const color = wholeColor(value);
    if (color) {
      this.#replace(index, color);
    }
  }

  /** On leaving a row, a short color expands and anything else returns to the stored color. */
  @action
  settleColor(index, event) {
    const color = storedColor(event.target.value);
    if (color) {
      this.#replace(index, color);
    }
    event.target.value = this.colors[index] ?? "";
  }

  @action
  handleMove(move) {
    this.args.onChange([...move.proposedToItems]);
  }

  @action
  removeColor(color, index) {
    this.args.onChange(this.colors.filter((_, i) => i !== index));
  }

  #replace(index, color) {
    if (this.colors[index] === color) {
      return;
    }
    const colors = [...this.colors];
    colors[index] = color;
    this.args.onChange(colors);
  }

  <template>
    <div class="color-list">
      <DReorderableList
        @allowCreate={{true}}
        @disabled={{@disabled}}
        @items={{this.colors}}
        @key={{INDEX_KEY}}
        @label={{colorLabel}}
        @onMove={{this.handleMove}}
        @onRemove={{this.removeColor}}
        @rowClass="color-list__row"
      >
        <:row as |color row|>
          <DColorInput
            aria-label={{rowLabel row.index}}
            @disabled={{@disabled}}
            @hashPrefix={{true}}
            @onChange={{fn this.editColor row.index}}
            @value={{color}}
            {{on "blur" (fn this.settleColor row.index)}}
          />
        </:row>
        <:create as |create|>
          <li class="color-list__add">
            <create.handleSlot />
            <DColorInput
              aria-label={{i18n "admin.site_settings.color_list.new_color"}}
              @disabled={{@disabled}}
              @hashPrefix={{true}}
              @onChange={{this.updateDraft}}
              @value={{this.draft}}
              {{on "keydown" this.addOnEnter}}
            />
            <DButton
              class="btn-default btn-small color-list__add-btn"
              @action={{this.add}}
              @disabled={{not this.canAdd}}
              @icon="plus"
              @label="admin.site_settings.color_list.add"
              @translatedTitle={{this.addTitle}}
            />
          </li>
        </:create>
      </DReorderableList>
    </div>
  </template>
}
