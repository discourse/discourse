export default function extractValue(desc) {
  return desc.value ||
    (typeof desc.initializer === 'function' && desc.initializer());
}
