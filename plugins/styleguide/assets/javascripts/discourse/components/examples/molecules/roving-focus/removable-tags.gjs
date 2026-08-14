import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import dRovingFocus from "discourse/ui-kit/modifiers/d-roving-focus";
import { i18n } from "discourse-i18n";

const TAGS = ["design", "keyboard", "release", "support"];

/**
 * The one example built from a real component rather than from bare markup, and the only one
 * where items are destroyed under the cursor.
 *
 * Two things only show up in this combination. Removing the focused tag unmounts the element
 * holding the cursor, so focus falls to the document body unless the modifier moves it, which
 * is the persistence behaviour the practice page calls essential. And the button defers its
 * action through the runloop, so the removal lands a tick after the key that asked for it,
 * which is the ordering a hand-written fixture does not reproduce.
 *
 * `itemsKey` is load-bearing here rather than an optimisation. The tags are component state the
 * modifier cannot observe, and it only reconciles when a named argument changes, so without the
 * key it never learns the item is gone and focus is left on the page. Persistence is on by
 * default but still depends on being told.
 *
 * When the last tag goes there is nothing left to hold a cursor, and the modifier deliberately
 * does nothing rather than inventing a destination. Landing somewhere sensible from there is
 * the consumer's decision, because only it knows what sits outside the group.
 */
export default class RovingFocusRemovableTagsExample extends Component {
  @tracked tags = TAGS;

  get rows() {
    return this.tags.map((id) => ({
      id,
      label: i18n(`styleguide.sections.roving_focus.tags.${id}`),
    }));
  }

  @action
  remove(id) {
    this.tags = this.tags.filter((tag) => tag !== id);
  }

  @action
  reset() {
    this.tags = TAGS;
  }

  <template>
    <div class="roving-demo__tags">
      <div
        class="roving-demo__tag-bar"
        role="toolbar"
        aria-label={{i18n "styleguide.sections.roving_focus.tags.label"}}
        {{dRovingFocus
          orientation="horizontal"
          itemSelector=".roving-demo__tag"
          entryFocus="first"
          itemsKey=this.tags
        }}
      >
        {{#each this.rows key="id" as |row|}}
          <DButton
            class="roving-demo__tag"
            @icon="xmark"
            @translatedLabel={{row.label}}
            @translatedAriaLabel={{i18n
              "styleguide.sections.roving_focus.tags.remove"
              tag=row.label
            }}
            @action={{fn this.remove row.id}}
          />
        {{/each}}
      </div>

      {{#unless this.tags.length}}
        <DButton
          class="roving-demo__reset"
          @translatedLabel={{i18n
            "styleguide.sections.roving_focus.tags.reset"
          }}
          @action={{this.reset}}
        />
      {{/unless}}
    </div>
  </template>
}
