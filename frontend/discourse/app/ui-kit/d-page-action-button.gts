import type { TOC } from "@ember/component/template-only";
import { hash } from "@ember/helper";
import type { ComponentLike } from "@glint/template";
import DButton, { type DButtonSignature } from "discourse/ui-kit/d-button";

/** The arguments a page action button forwards to `DButton`. */
export interface DPageActionButtonArgs {
  /** Called on click. */
  action?: () => void;

  /** The ID of an icon shown in the button. */
  icon?: string;

  /** Whether the button shows a loading state. */
  isLoading?: boolean;

  /** The translation key of the label. */
  label?: string;

  /** A route the button links to, in place of `@action`. */
  route?: string;

  /** The models of `@route`. */
  routeModels?: DButtonSignature["Args"]["routeModels"];

  /** The translation key of the title. */
  title?: string;

  /** The label, already translated. */
  translatedLabel?: string;
}

interface DPageActionButtonSignature {
  Args: DPageActionButtonArgs & {
    /** Whether the button is disabled. */
    disabled?: boolean;
  };

  Element: DButtonSignature["Element"];
}

interface DPageActionListItemSignature {
  Args: DPageActionButtonArgs;
  Element: DButtonSignature["Element"];
}

interface WrappedButtonSignature {
  Blocks: {
    /** The button to wrap. */
    default: [];
  };
}

interface WrappedActionListItemSignature {
  Blocks: {
    default: [
      /** The classes to style the wrapped button as a list item. */
      options: {
        /** The class of a list item button. */
        buttonClass: string;
      },
    ];
  };
}

export const DPageActionButton: TOC<DPageActionButtonSignature> = <template>
  <DButton
    class="d-page-action-button btn-small"
    ...attributes
    @action={{@action}}
    @disabled={{@disabled}}
    @icon={{@icon}}
    @isLoading={{@isLoading}}
    @label={{@label}}
    @route={{@route}}
    @routeModels={{@routeModels}}
    @title={{@title}}
    @translatedLabel={{@translatedLabel}}
  />
</template>;

/**
 * This is used for cases where there is another component,
 * e.g. UppyBackupUploader, that is a button which cannot use
 * PrimaryButton and so on directly. This should be used very rarely,
 * most cases are covered by the other button types.
 */
export const WrappedButton: TOC<WrappedButtonSignature> = <template>
  <span class="d-page-action-wrapped-button">{{yield}}</span>
</template>;

/**
 * No buttons here pass in an `@icon` by design. They are okay to
 * use on dropdown list items, but our UI guidelines do not allow them
 * on regular buttons.
 */
export const PrimaryButton: TOC<DPageActionButtonSignature> = <template>
  <DPageActionButton
    class="btn-primary"
    ...attributes
    @action={{@action}}
    @disabled={{@disabled}}
    @icon={{@icon}}
    @isLoading={{@isLoading}}
    @label={{@label}}
    @route={{@route}}
    @routeModels={{@routeModels}}
    @title={{@title}}
    @translatedLabel={{@translatedLabel}}
  />
</template>;

export const DangerButton: TOC<DPageActionListItemSignature> = <template>
  <DPageActionButton
    class="btn-danger"
    ...attributes
    @action={{@action}}
    @icon={{@icon}}
    @isLoading={{@isLoading}}
    @label={{@label}}
    @route={{@route}}
    @routeModels={{@routeModels}}
    @title={{@title}}
    @translatedLabel={{@translatedLabel}}
  />
</template>;

export const DefaultButton: TOC<DPageActionListItemSignature> = <template>
  <DPageActionButton
    class="btn-default"
    ...attributes
    @action={{@action}}
    @icon={{@icon}}
    @isLoading={{@isLoading}}
    @label={{@label}}
    @route={{@route}}
    @routeModels={{@routeModels}}
    @title={{@title}}
    @translatedLabel={{@translatedLabel}}
  />
</template>;

export const DPageActionListItem: TOC<DPageActionListItemSignature> = <template>
  <li class="dropdown-menu__item d-page-action-list-item">
    <DPageActionButton
      class="btn-transparent"
      ...attributes
      @action={{@action}}
      @icon={{@icon}}
      @isLoading={{@isLoading}}
      @label={{@label}}
      @route={{@route}}
      @routeModels={{@routeModels}}
      @title={{@title}}
      @translatedLabel={{@translatedLabel}}
    />
  </li>
</template>;

/**
 * This is used for cases where there is another component,
 * e.g. UppyBackupUploader, that is a button which cannot use
 * PrimaryActionListItem and so on directly. This should be used very rarely,
 * most cases are covered by the other list types.
 */
export const WrappedActionListItem: TOC<WrappedActionListItemSignature> =
  <template>
    <li
      class="dropdown-menu__item d-page-action-list-item d-page-action-wrapped-list-item"
    >
      {{yield (hash buttonClass="btn-transparent")}}
    </li>
  </template>;

/**
 * It is not a mistake that there is no PrimaryActionListItem here, in a list
 * there is no need for blue text.
 */
export const DefaultActionListItem: TOC<DPageActionListItemSignature> =
  <template>
    <DPageActionListItem
      class="btn-default"
      ...attributes
      @action={{@action}}
      @icon={{@icon}}
      @isLoading={{@isLoading}}
      @label={{@label}}
      @route={{@route}}
      @routeModels={{@routeModels}}
      @title={{@title}}
      @translatedLabel={{@translatedLabel}}
    />
  </template>;

export const DangerActionListItem: TOC<DPageActionListItemSignature> =
  <template>
    <DPageActionListItem
      class="btn-danger"
      ...attributes
      @action={{@action}}
      @icon={{@icon}}
      @isLoading={{@isLoading}}
      @label={{@label}}
      @route={{@route}}
      @routeModels={{@routeModels}}
      @title={{@title}}
      @translatedLabel={{@translatedLabel}}
    />
  </template>;

/**
 * The action components a page header yields. The buttons and the list items
 * share it, so the same block renders on desktop and in the mobile menu.
 */
export interface DPageActions {
  /** The main action. */
  Primary: ComponentLike<DPageActionButtonSignature>;

  /** A secondary action. */
  Default: ComponentLike<DPageActionListItemSignature>;

  /** A destructive action. */
  Danger: ComponentLike<DPageActionListItemSignature>;

  /** Wraps a button that cannot be one of the others. */
  Wrapped: ComponentLike<{
    Blocks: { default: [options?: { buttonClass: string }] };
  }>;
}
