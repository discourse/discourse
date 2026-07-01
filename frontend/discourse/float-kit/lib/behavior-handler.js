export function processBehavior({ nativeEvent, defaultBehavior, handler }) {
  let result = defaultBehavior;

  if (handler) {
    if (typeof handler === "function") {
      const customEvent = {
        ...defaultBehavior,
        nativeEvent,
        changeDefault(changes) {
          result = { ...defaultBehavior, ...changes };
          Object.assign(this, changes);
        },
      };
      customEvent.changeDefault = customEvent.changeDefault.bind(customEvent);
      handler(customEvent);
    } else {
      result = { ...defaultBehavior, ...handler };
    }
  }

  return result;
}
