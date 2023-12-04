import lookupService from "../-private/lookup-service.js";

// TODO: instead of passing-through the actual router service, we probably want
// to return a shim that restricts the APIs we actually want to expose, but the
// same probably applies, perhaps to a lesser extent, to all the services here.
export default lookupService("router");
