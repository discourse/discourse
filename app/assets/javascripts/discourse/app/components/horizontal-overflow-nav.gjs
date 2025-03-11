{{! template-lint-disable no-pointer-down-event-binding }}
{{! template-lint-disable no-invalid-interactive }}

<nav
  class="horizontal-overflow-nav {{if this.hasScroll 'has-scroll'}}"
  aria-label={{@ariaLabel}}
>
  {{#if this.hasScroll}}
    <a
      role="button"
      {{on "mousedown" this.horizontalScroll}}
      {{on "mouseup" this.stopScroll}}
      {{on "mouseleave" this.stopScroll}}
      data-direction="left"
      class={{concat-class
        "horizontal-overflow-nav__scroll-left"
        (if this.hideLeftScroll "disabled")
      }}
    >
      {{d-icon "chevron-left"}}
    </a>
  {{/if}}

  <ul
    {{on-resize this.onResize}}
    {{on "scroll" this.onScroll}}
    {{did-insert this.scrollToActive}}
    {{on "mousedown" this.scrollDrag}}
    class="nav-pills action-list {{@className}}"
    ...attributes
  >
    {{yield}}
  </ul>

  {{#if this.hasScroll}}
    <a
      role="button"
      {{on "mousedown" this.horizontalScroll}}
      {{on "mouseup" this.stopScroll}}
      {{on "mouseleave" this.stopScroll}}
      class={{concat-class
        "horizontal-overflow-nav__scroll-right"
        (if this.hideRightScroll "disabled")
      }}
    >
      {{d-icon "chevron-right"}}
    </a>
  {{/if}}
</nav>