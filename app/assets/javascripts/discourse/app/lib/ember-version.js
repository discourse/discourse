import { VERSION } from "@ember/version";

const parts = VERSION.split(".");

export const EMBER_MAJOR_VERSION = parseInt(parts[0], 10);
