module.exports = function assert(value, message) {
  if (!value) {
    throw new Error(message);
  }
};
