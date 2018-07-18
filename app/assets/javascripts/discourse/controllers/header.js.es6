import { addFlagProperty as realAddFlagProperty } from "discourse/components/site-header";
import deprecated from "discourse-common/lib/deprecated";

export function addFlagProperty(prop) {
  deprecated(
    "importing `addFlagProperty` is deprecated. Use the PluginAPI instead"
  );
  realAddFlagProperty(prop);
}
