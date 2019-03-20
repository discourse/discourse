/* eslint-disable */
Object.setPrototypeOf =
  Object.setPrototypeOf ||
  function(obj, proto) {
    obj.__proto__ = proto;
    return obj;
  };
/* eslint-enable */
