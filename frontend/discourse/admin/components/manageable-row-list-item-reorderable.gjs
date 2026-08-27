import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import { i18n } from "discourse-i18n";

/**
 * One row of a toggleable, ordered admin list: its text and its enable
 * switch.
 *
 * Reordering is not drawn here. The surrounding reorderable list owns the
 * handle, the drag, the move menu and the announcements, so a row only has to
 * describe itself.
 */
// TODO (ui-kit-reorderable-list-cleanup) rename this over
// `manageable-row-list-item.gjs` once the change ships.
const ManageableRowListItem = <template>
  <div class="manageable-row-list__row-content">
    <div class="manageable-row-list__row-text">
      <div class="manageable-row-list__row-heading">
        <span class="manageable-row-list__title">{{@row.title}}</span>
        {{#if @row.label}}
          <span class="db-report__label">
            {{@row.label}}
          </span>
        {{/if}}
      </div>
      {{#if @row.description}}
        <p class="manageable-row-list__description">{{@row.description}}</p>
      {{/if}}
    </div>

    <DToggleSwitch
      @state={{@row.enabled}}
      disabled={{@toggleDisabled}}
      aria-label={{i18n
        (if
          @row.enabled
          (concat @ariaLabelPrefix ".disable")
          (concat @ariaLabelPrefix ".enable")
        )
        title=@row.title
      }}
      {{on "click" (fn @onToggle @row)}}
    />
  </div>
</template>;

export default ManageableRowListItem;
