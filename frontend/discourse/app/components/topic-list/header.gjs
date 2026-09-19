import { hash } from "@ember/helper";
import { applyValueTransformer } from "discourse/lib/transformer";

const Header = <template>
  <tr>
    {{#each @columns as |entry|}}
      <entry.value.header
        @activeOrder={{@order}}
        @ascending={{@ascending}}
        @bulkSelectEnabled={{@bulkSelectEnabled}}
        @bulkSelectHelper={{@bulkSelectHelper}}
        @canBulkSelect={{@canBulkSelect}}
        @canDoBulkActions={{@canDoBulkActions}}
        @category={{@category}}
        @changeSort={{@changeSort}}
        @name={{@listTitle}}
        @showBulkToggle={{@toggleInTitle}}
        @sortable={{applyValueTransformer
          "topic-list-header-sortable-column"
          @sortable
          (hash category=@category name=@name)
        }}
      />
    {{/each}}
  </tr>
</template>;

export default Header;
