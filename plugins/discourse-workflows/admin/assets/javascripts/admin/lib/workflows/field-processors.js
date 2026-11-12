const PROCESSORS = [];

export default function processFields(fields, ...args) {
  return PROCESSORS.reduce(
    (result, processor) => processor(result, ...args),
    fields
  );
}
