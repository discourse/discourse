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
export const WrappedButton = <template>
  <span class="wrapped-admin-action-button">{{yield}}</span>
</template>;

export const AdminPageActionListItem = <template>
  <li class="dropdown-menu__item admin-page-action-list-item">
    <AdminPageActionButton
      class="btn-transparent"
      ...attributes
      @action={{@action}}
      @route={{@route}}
      @routeModels={{@routeModels}}
      @label={{@label}}
      @title={{@title}}
      @icon={{@icon}}
      @isLoading={{@isLoading}}
    />
  </li>
</template>;
export const WrappedActionListItem = <template>
  <li
    class="dropdown-menu__item admin-page-action-list-item admin-page-action-wrapped-list-item"
  >
    {{yield}}
  </li>
</template>;
export const PrimaryActionListItem = <template>
  <AdminPageActionListItem
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
export const DefaultActionListItem = <template>
  <AdminPageActionListItem
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
export const DangerActionListItem = <template>
  <AdminPageActionListItem
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
