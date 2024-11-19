import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import i18n from "discourse-common/helpers/i18n";

const AdminConfigAreaEmptyList = <template>
  <div class="admin-config-area-empty-list">
    {{i18n @emptyLabel}}
    <DButton
      @label={{@ctaLabel}}
      class={{concatClass
        "btn-default btn-small admin-config-area-empty-list__cta-button"
        @ctaClass
      }}
      @action={{@ctaAction}}
      @route={{@ctaRoute}}
    />
  </div>
</template>;

export default AdminConfigAreaEmptyList;
