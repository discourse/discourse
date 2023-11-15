import { setOwner } from "@ember/application";
import {
  capabilities,
  getComponentTemplate,
  setComponentManager,
  setComponentTemplate,
} from "@ember/component";
import { assert } from "@ember/debug";

export default class Widget {
  static {
    const WidgetComponentManager = {
      capabilities: capabilities("3.13", {
        asyncLifecycleCallbacks: false,
        destructor: false,
        updateHook: false,
      }),

      createComponent(widget) {
        assert("Must not be null", widget !== null);
        assert("Must be an object", typeof widget === "object");
        assert("Must be an instance of Widget", #widget in widget);
        return widget;
      },

      getContext(widget) {
        assert("Must not be null", widget !== null);
        assert("Must be an object", typeof widget === "object");
        assert("Must be an instance of Widget", #widget in widget);
        return widget;
      },
    };

    setComponentManager(() => WidgetComponentManager, this.prototype);
  }

  #widget = true;

  constructor(owner) {
    setOwner(this, owner);

    if (getComponentTemplate(this) === undefined) {
      const Template = getComponentTemplate(this.constructor);

      if (Template) {
        setComponentTemplate(Template, this.constructor.prototype);
      }
    }
  }

  get isActive() {
    return true;
  }
}
