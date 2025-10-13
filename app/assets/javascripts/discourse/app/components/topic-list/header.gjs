import { hash } from "@ember/helper";
import { applyValueTransformer } from "discourse/lib/transformer";

const Header = <template>
  <tr>
    {{#each @columns as |entry|}}
      <entry.value.header
        @sortable={{applyValueTransformer
          "topic-list-header-sortable-column"
          @sortable
          (hash category=@category name=@name)
        }}
        @activeOrder={{@order}}
        @changeSort={{@changeSort}}
        @ascending={{@ascending}}
        @category={{@category}}
        @name={{@listTitle}}
        @bulkSelectEnabled={{@bulkSelectEnabled}}
        @showBulkToggle={{@toggleInTitle}}
        @canBulkSelect={{@canBulkSelect}}
        @canDoBulkActions={{@canDoBulkActions}}
        @bulkSelectHelper={{@bulkSelectHelper}}
      />
    {{/each}}
  </tr>
</template>;

export default Header;
