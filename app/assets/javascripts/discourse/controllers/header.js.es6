import { addFlagProperty as realAddFlagProperty } from 'discourse/components/site-header';

export function addFlagProperty(prop) {
  Ember.warn("importing `addFlagProperty` is deprecated. Use the PluginAPI instead");
  realAddFlagProperty(prop);
}
