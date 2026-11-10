import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  // Rings arrive over MessageBus whether or not any live UI is on screen,
  // so the calls service starts listening as soon as the app boots.
  if (api.getCurrentUser()) {
    api.container.lookup("service:live-calls").listen();
  }
});
