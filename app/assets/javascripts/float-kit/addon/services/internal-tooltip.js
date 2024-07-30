import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";

/*
  This service holds the current tooltip displayed when using <DTooltip> component.
  All of these tooltips share a common portal outlet element, which means
  we have to ensure we close them before their html is replaced, otherwise
  we end up with a detached element in the DOM and unexpected behavior.
*/
export default class InternalTooltip extends Service {
  @tracked activeTooltip;
}
