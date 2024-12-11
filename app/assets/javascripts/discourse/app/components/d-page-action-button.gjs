import { hash } from "@ember/helper";
import DButton from "discourse/components/d-button";

export const DPageActionButton = <template>
  <DButton
    class="d-page-action-button btn-small"
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
  <span class="d-page-action-wrapped-button">{{yield}}</span>
</template>;

// No buttons here pass in an @icon by design. They are okay to
// use on dropdown list items, but our UI guidelines do not allow them
// on regular buttons.
export const PrimaryButton = <template>
  <DPageActionButton
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
  <DPageActionButton
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
  <DPageActionButton
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

export const DPageActionListItem = <template>
  <li class="dropdown-menu__item d-page-action-list-item">
    <DPageActionButton
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
    class="dropdown-menu__item d-page-action-list-item d-page-action-wrapped-list-item"
  >
    {{yield (hash buttonClass="btn-transparent")}}
  </li>
</template>;

// It is not a mistake that there is no PrimaryActionListItem here, in a list
// there is no need for blue text.
export const DefaultActionListItem = <template>
  <DPageActionListItem
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
  <DPageActionListItem
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
