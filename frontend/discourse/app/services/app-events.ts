import Evented from "@ember/object/evented";
import Service from "@ember/service";

// `Service.extend(Evented)` mixes the Evented methods (`on`, `off`, `one`, `trigger`, `has`)
// in at runtime, but Ember's `.extend` typing does not surface them. Merging an interface of
// the same name adds them to the class type — the standard Ember pattern for a
// mixin-augmented service, hence the suppressed declaration-merging lint rules.
// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
interface AppEvents extends Evented {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
class AppEvents extends Service.extend(Evented) {}

export default AppEvents;
