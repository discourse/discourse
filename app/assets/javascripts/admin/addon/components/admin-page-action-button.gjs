import DButton from "discourse/components/d-button";

export const AdminPageActionButton = <template>
  <DButton
    class="admin-page-action-button btn-small"
    ...attributes
    @action={{@action}}
    @route={{@route}}
    @routeModels={{@routeModels}}
    @label={{@label}}
    @title={{@title}}
    @icon={{@icon}}
    @isLoading={{@isLoading}}
  />
</template>;
export const PrimaryButton = <template>
  <AdminPageActionButton
    class="btn-primary"
    ...attributes
    @action={{@action}}
    @route={{@route}}
    @routeModels={{@routeModels}}
    @label={{@label}}
    @title={{@title}}
    @icon={{@icon}}
    @isLoading={{@isLoading}}
  />
</template>;
export const DangerButton = <template>
  <AdminPageActionButton
    class="btn-danger"
    ...attributes
    @action={{@action}}
    @route={{@route}}
    @routeModels={{@routeModels}}
    @label={{@label}}
    @title={{@title}}
    @icon={{@icon}}
    @isLoading={{@isLoading}}
  />
</template>;
export const DefaultButton = <template>
  <AdminPageActionButton
    class="btn-default"
    ...attributes
    @action={{@action}}
    @route={{@route}}
    @routeModels={{@routeModels}}
    @label={{@label}}
    @title={{@title}}
    @icon={{@icon}}
    @isLoading={{@isLoading}}
  />
</template>;
