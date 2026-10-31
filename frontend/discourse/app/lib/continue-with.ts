/** Continues with a value now, or with a promise's value when it settles. */
export function continueWith<T, R>(
  value: T | Promise<T>,
  next: (value: T) => R | Promise<R>
): R | Promise<R> {
  return value instanceof Promise ? value.then(next) : next(value);
}
