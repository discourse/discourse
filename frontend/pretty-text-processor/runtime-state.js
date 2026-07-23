// Per-invocation state shared between entry.js (which sets it) and the
// discourse/lib/helpers shim (which reads avatarSizes). Set at the start of each
// __PrettyText call; avoids exposing these as globals.
export const runtime = { paths: {}, avatarSizes: undefined };
