import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq, not } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import categoryBadge from "discourse/helpers/category-badge";
import withEventValue from "discourse/helpers/with-event-value";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

class Entry {
  @tracked position;

  constructor({ position, depth, category, descendantCount }) {
    this.position = position;
    this.depth = depth;
    this.category = category;
    this.descendantCount = descendantCount;
  }
}

export default class ReorderCategories extends Component {
  @service site;

  @tracked changed = false;
  @tracked entries = this.reorder();
  @tracked highlightedCategoryId = null;

  get sortedEntries() {
    return this.entries.sortBy("position");
  }

  reorder(from) {
    from ??= this.site.categories.map((category) => ({
      category,
      position: category.position,
    }));

    return this.createEntries([...from.sortBy("position")]);
  }

  /**
   * 1. Make sure all categories have unique position numbers.
   * 2. Place sub-categories after their parent categories while maintaining
   *    the same relative order.
   *
   *    e.g.
   *      parent/c2/c1          parent
   *      parent/c1             parent/c1
   *      parent          =>    parent/c2
   *      other                 parent/c2/c1
   *      parent/c2             other
   **/
  createEntries(from, position = 0, categoryId = null, depth = 0) {
    let result = [];

    for (const entry of from) {
      if (
        (categoryId === null && !entry.category.parent_category_id) ||
        entry.category.parent_category_id === categoryId
      ) {
        const descendants = this.createEntries(
          from,
          position + result.length + 1,
          entry.category.id,
          depth + 1
        );

        result = [
          ...result,
          new Entry({
            position: position + result.length,
            depth,
            category: entry.category,
            descendantCount: descendants.length,
          }),
          ...descendants,
        ];
      }
    }

    return result;
  }

  @action
  move(entry, delta) {
    let targetPosition = entry.position + delta;

    // Adjust target position for sub-categories
    if (delta > 0) {
      // Moving down (position gets larger)
      if (entry.descendantCount) {
        // This category has subcategories, adjust targetPosition to account for them
        if (entry.descendantCount >= delta) {
          // Only apply offset if target position is occupied by a subcategory
          // Seems weird but fixes a UX quirk
          targetPosition += entry.descendantCount;
        }
      }
    } else {
      // Moving up (position gets smaller)
      const ancestors = this.sortedEntries[targetPosition]?.category?.ancestors;
      if (ancestors) {
        // Target category is a subcategory, adjust targetPosition to account for ancestors
        const highestAncestorEntry = this.sortedEntries.findBy(
          "category.id",
          ancestors[0].id
        );
        targetPosition = highestAncestorEntry.position;
      }
    }

    // Adjust target position for range bounds
    if (targetPosition >= this.entries.length) {
      // Set to max
      targetPosition = this.entries.length - 1;
    } else if (targetPosition < 0) {
      // Set to min
      targetPosition = 0;
    }

    // Update other categories between current and target position
    for (const e of this.sortedEntries) {
      if (delta > 0) {
        // Moving down (position gets larger)
        if (e.position > entry.position && e.position <= targetPosition) {
          e.position -= 1;
        }
      } else {
        // Moving up (position gets smaller)
        if (e.position < entry.position && e.position >= targetPosition) {
          e.position += 1;
        }
      }
    }

    // Update this category's position to target position
    entry.position = targetPosition;

    this.entries = this.reorder(this.sortedEntries);
    this.changed = true;

    this.toggleHighlight(entry.category.id);
  }

  @action
  toggleHighlight(categoryId) {
    this.highlightedCategoryId = categoryId;
    setTimeout(() => {
      if (this.highlightedCategoryId === categoryId) {
        this.highlightedCategoryId = null;
      }
    }, 3000);
  }

  @action
  change(entry, newPosition) {
    const delta = parseInt(newPosition, 10) - entry.position;
    this.move(entry, delta);
  }

  @action
  async save() {
    const entries = this.reorder(this.sortedEntries);

    const data = {};
    for (const { category, position } of entries) {
      data[category.id] = position;
    }

    try {
      await ajax("/categories/reorder", {
        type: "POST",
        data: { mapping: JSON.stringify(data) },
      });
      window.location.reload();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <DModal
      @title={{i18n "categories.reorder.title"}}
      @closeModal={{@closeModal}}
      @inline={{@inline}}
      class="reorder-categories"
    >
      <:body>
        <table>
          <thead>
            <th>{{i18n "categories.category"}}</th>
            <th class="reorder-categories__header-position">
              {{i18n "categories.reorder.position"}}
            </th>
          </thead>
          <tbody>
            {{#each this.sortedEntries as |entry|}}
              <tr
                data-category-id={{entry.category.id}}
                class={{if
                  (eq this.highlightedCategoryId entry.category.id)
                  "highlighted"
                }}
              >
                <td>
                  <div class={{concat "reorder-categories-depth-" entry.depth}}>
                    {{categoryBadge entry.category allowUncategorized="true"}}
                  </div>
                </td>

                <td>
                  <div class="reorder-categories-actions">
                    <input
                      {{on "change" (withEventValue (fn this.change entry))}}
                      value={{entry.position}}
                      type="number"
                      min="0"
                    />
                    <DButton
                      @action={{fn this.move entry -1}}
                      @icon="arrow-up"
                      class="btn-default no-text move-up"
                    />
                    <DButton
                      @action={{fn this.move entry 1}}
                      @icon="arrow-down"
                      class="btn-default no-text move-down"
                    />
                  </div>
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      </:body>

      <:footer>
        <DButton
          @action={{this.save}}
          @label="categories.reorder.save"
          @disabled={{not this.changed}}
          class="btn-primary"
        />
      </:footer>
    </DModal>
  </template>
}
