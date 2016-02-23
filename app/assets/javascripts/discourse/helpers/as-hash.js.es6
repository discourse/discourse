// Note: Later versions of ember include `hash`
export default function hashHelper(params) {
  const hash = {};
  Object.keys(params.hash).forEach(k => {
    hash[k] = params.data.view.getStream(params.hash[k]).value();
  });
  return hash;
}
