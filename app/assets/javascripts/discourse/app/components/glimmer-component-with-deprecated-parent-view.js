import Component from "@glimmer/component";
import {
  CustomComponentManager,
  setInternalComponentManager,
} from "@glimmer/manager";
import EmberGlimmerComponentManager from "@glimmer/component/-private/ember-component-manager";
import { valueForRef } from "@glimmer/reference";

class GlimmerComponentWithParentViewManager extends CustomComponentManager {
  create(
    owner,
    componentClass,
    args,
    environment,
    dynamicScope,
    callerSelfRef
  ) {
    const result = super.create(...arguments);

    result.component.parentView = dynamicScope.view;
    dynamicScope.view = result.component;

    result.component._target = valueForRef(callerSelfRef);

    return result;
  }

  getCapabilities() {
    return { ...super.getCapabilities(), createCaller: true };
  }
}

/**
 * This component has a lightly-extended version of Ember's default Glimmer component manager.
 * It gives Glimmer components the ability to reference their parent view which can be useful
 * when building backwards-compatible versions of components. Any use of the parentView property
 * of the component should be considered deprecated.
 */
export default class GlimmerComponentWithDeprecatedParentView extends Component {}

setInternalComponentManager(
  new GlimmerComponentWithParentViewManager(
    (owner) => new EmberGlimmerComponentManager(owner)
  ),
  GlimmerComponentWithDeprecatedParentView
);
