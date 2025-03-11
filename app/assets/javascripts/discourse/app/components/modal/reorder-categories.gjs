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
                {{category-badge entry.category allowUncategorized="true"}}
              </div>
            </td>

            <td>
              <div class="reorder-categories-actions">
                <input
                  {{on "change" (with-event-value (fn this.change entry))}}
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