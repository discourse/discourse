import DOverflowControls from "discourse/ui-kit/d-overflow-controls";

const ROWS = Array.from({ length: 20 }, (_, index) => `Row ${index + 1}`);

export default <template>
  <div
    class="styleguide-overflow-controls styleguide-overflow-controls--narrow"
  >
    <DOverflowControls @class="styleguide-overflow-controls__column">
      {{#each ROWS as |row|}}
        <div class="styleguide-overflow-controls__row">{{row}}</div>
      {{/each}}
    </DOverflowControls>
  </div>
</template>
