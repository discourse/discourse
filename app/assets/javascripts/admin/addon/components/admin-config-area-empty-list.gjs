import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";

const AdminConfigAreaEmptyList = <template>
  <div class="admin-config-area-empty-list">
    {{htmlSafe @emptyLabel}}

    {{#if @ctaLabel}}
      <DButton
        @label={{@ctaLabel}}
        class={{concatClass
          "btn-default btn-small admin-config-area-empty-list__cta-button"
          @ctaClass
        }}
        @action={{@ctaAction}}
        @route={{@ctaRoute}}
      />
    {{/if}}
  </div>
</template>;

export default AdminConfigAreaEmptyList;
