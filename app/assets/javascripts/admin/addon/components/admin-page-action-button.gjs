import { hash } from "@ember/helper";
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

// This is used for cases where there is another component,
// e.g. UppyBackupUploader, that is a button which cannot use
// PrimaryButton and so on directly. This should be used very rarely,
// most cases are covered by the other button types.
export const WrappedButton = <template>
  <span class="admin-page-action-wrapped-button">{{yield}}</span>
</template>;

// No buttons here pass in an @icon by design. They are okay to
// use on dropdown list items, but our UI guidelines do not allow them
// on regular buttons.
export const PrimaryButton = <template>
  <AdminPageActionButton
    class="btn-primary"
    ...attributes
    @action={{@action}}
    @route={{@route}}
    @routeModels={{@routeModels}}
    @label={{@label}}
    @title={{@title}}
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
    @isLoading={{@isLoading}}
  />
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

// This is used for cases where there is another component,
// e.g. UppyBackupUploader, that is a button which cannot use
// PrimaryActionListItem and so on directly. This should be used very rarely,
// most cases are covered by the other list types.
export const WrappedActionListItem = <template>
  <li
    class="dropdown-menu__item admin-page-action-list-item admin-page-action-wrapped-list-item"
  >
    {{yield (hash buttonClass="btn-transparent")}}
  </li>
</template>;

// It is not a mistake that `btn-default` is used here, in a list
// there is no need for blue text.
export const PrimaryActionListItem = <template>
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
