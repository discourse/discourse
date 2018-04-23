export default function wrap(wrapperFunction, exceptionClass) {
  return function (target, key, descriptor) {
    const originalFunction = descriptor.value;
    if (typeof wrapperFunction === "function") {
      descriptor.value = function(...args) {
        try {
          wrapperFunction.apply(this, ...args);
          return originalFunction.apply(this, ...args);
        } catch (exception) {
          if (!exceptionClass || exceptionClass && !exception instanceof exceptionClass) {
            throw exception;
          }
        }
      };
    }

    return descriptor;
  };
}
