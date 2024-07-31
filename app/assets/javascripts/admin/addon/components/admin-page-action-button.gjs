import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";

const AdminPageActionButton = <template>
  <DButton
    class={{concatClass
      "admin-page-action-button"
      @buttonClasses
      @additionalClasses
    }}
    @action={{@action}}
    @label={{@label}}
    @title={{@title}}
    @icon={{@icon}}
    @isLoading={{@isLoading}}
  />
</template>;

export default AdminPageActionButton;
