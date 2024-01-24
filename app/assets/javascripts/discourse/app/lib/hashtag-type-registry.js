let hashtagTypeClasses = {};
export function registerHashtagType(type, typeClassInstance) {
  hashtagTypeClasses[type] = typeClassInstance;
}
export function cleanUpHashtagTypeClasses() {
  hashtagTypeClasses = {};
}
export function getHashtagTypeClasses() {
  return hashtagTypeClasses;
}
