import DButton from "discourse/ui-kit/d-button";
import DComboButton from "discourse/ui-kit/d-combo-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";

const noop = () => {};

// Both variants are shown because the joined seam between the halves is styled
// differently for each, and an outlined regression is invisible on a filled one.
export default <template>
  <div class="styleguide--combo-button">
    <DComboButton @hasMenu={{true}} @btnTypeClass="btn-default" as |combo|>
      <combo.Button @translatedLabel="New topic" @icon="far-pen-to-square" />
      <combo.Menu @identifier="styleguide-combo-default">
        <DDropdownMenu as |dropdown|>
          <dropdown.item>
            <DButton
              @translatedLabel="Resume draft"
              @icon="reply"
              @action={{noop}}
            />
          </dropdown.item>
        </DDropdownMenu>
      </combo.Menu>
    </DComboButton>

    <DComboButton @hasMenu={{true}} @btnTypeClass="btn-primary" as |combo|>
      <combo.Button @translatedLabel="New topic" @icon="far-pen-to-square" />
      <combo.Menu @identifier="styleguide-combo-primary">
        <DDropdownMenu as |dropdown|>
          <dropdown.item>
            <DButton
              @translatedLabel="Resume draft"
              @icon="reply"
              @action={{noop}}
            />
          </dropdown.item>
        </DDropdownMenu>
      </combo.Menu>
    </DComboButton>

    <DComboButton @btnTypeClass="btn-default" as |combo|>
      <combo.Button @translatedLabel="No menu" @icon="far-pen-to-square" />
    </DComboButton>
  </div>
</template>
