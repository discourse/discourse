import { cancel, later } from "@ember/runloop";
import { modifier } from "ember-modifier";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

const DEFAULT_HIDE_DELAY = 500;

const hoverVisibility = modifier(function (element, _, named) {
  const delay = named.delay ?? DEFAULT_HIDE_DELAY;
  const svg = element.closest("svg");
  const target =
    named.hoverTarget ??
    (named.hoverSelector
      ? element.closest(named.hoverSelector)
      : (svg?.querySelector(named.hoverQuery) ?? element.parentElement));

  const el =
    named.visibilityTarget ??
    svg?.querySelector(named.visibilityQuery) ??
    element;
  let timer = null;

  function show() {
    cancel(timer);
    el.classList.add("is-visible");
  }

  function scheduleHide() {
    cancel(timer);
    timer = later(() => el.classList.remove("is-visible"), delay);
  }

  target?.addEventListener("mouseenter", show);
  target?.addEventListener("mouseleave", scheduleHide);
  element.addEventListener("mouseenter", show);
  element.addEventListener("mouseleave", scheduleHide);

  return () => {
    cancel(timer);
    target?.removeEventListener("mouseenter", show);
    target?.removeEventListener("mouseleave", scheduleHide);
    element.removeEventListener("mouseenter", show);
    element.removeEventListener("mouseleave", scheduleHide);
  };
});

export default <template>
  <div
    class={{dConcatClass "workflow-canvas-toolbar" (if @inline "--inline")}}
    {{hoverVisibility
      hoverTarget=@hoverTarget
      hoverSelector=@hoverSelector
      hoverQuery=@hoverQuery
      visibilityTarget=@visibilityTarget
      visibilityQuery=@visibilityQuery
      delay=@hideDelay
    }}
  >
    {{yield}}
  </div>
</template>
