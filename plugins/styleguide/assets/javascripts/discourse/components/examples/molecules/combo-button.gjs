import DButton from "discourse/ui-kit/d-button";
import DComboButton from "discourse/ui-kit/d-combo-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";

const noop = () => {};

// Both variants are shown because the joined seam between the halves is styled
// differently for each, and an outlined regression is invisible on a filled one.
export default <template>
  <div class="styleguide--combo-button">
    <DComboButton @btnTypeClass="btn-default" @hasMenu={{true}} as |combo|>
      <combo.Button @icon="far-pen-to-square" @translatedLabel="New topic" />
      <combo.Menu @identifier="styleguide-combo-default">
        <DDropdownMenu as |dropdown|>
          <dropdown.item>
            <DButton
              @action={{noop}}
              @icon="reply"
              @translatedLabel="Resume draft"
            />
          </dropdown.item>
        </DDropdownMenu>
      </combo.Menu>
    </DComboButton>

    <DComboButton @btnTypeClass="btn-primary" @hasMenu={{true}} as |combo|>
      <combo.Button @icon="far-pen-to-square" @translatedLabel="New topic" />
      <combo.Menu @identifier="styleguide-combo-primary">
        <DDropdownMenu as |dropdown|>
          <dropdown.item>
            <DButton
              @action={{noop}}
              @icon="reply"
              @translatedLabel="Resume draft"
            />
          </dropdown.item>
        </DDropdownMenu>
      </combo.Menu>
    </DComboButton>

    <DComboButton @btnTypeClass="btn-default" as |combo|>
      <combo.Button @icon="far-pen-to-square" @translatedLabel="No menu" />
    </DComboButton>
  </div>
</template>
