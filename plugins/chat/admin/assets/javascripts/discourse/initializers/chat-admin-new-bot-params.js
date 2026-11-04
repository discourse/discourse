import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  if (!api.container.lookup("service:site-settings").chat_enabled) {
    return;
  }

  api.registerValueTransformer(
    "admin-new-bot-params",
    ({ value, context }) => ({
      ...value,
      chat_discoverable: Boolean(context.data.chat_discoverable),
    })
  );
});
