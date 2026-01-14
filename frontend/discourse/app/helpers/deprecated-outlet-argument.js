export default function deprecatedOutletArgument(options) {
  return new DeprecatedOutletArgument(options);
}

export function isDeprecatedOutletArgument(value) {
  return value instanceof DeprecatedOutletArgument;
}

class DeprecatedOutletArgument {
  #message;
  #silence;
  #valueRef;

  constructor(options) {
    this.#message = options.message;
    this.#valueRef = () => options.value;
    this.#silence = options.silence;

    this.options = {
      id: options.id || "discourse.plugin-connector.deprecated-arg",
      since: options.since,
      dropFrom: options.dropFrom,
      url: options.url,
      raiseError: options.raiseError,
    };
  }

  get message() {
    return this.#message;
  }

  get silence() {
    return this.#silence;
  }

  get value() {
    return this.#valueRef();
  }
}
