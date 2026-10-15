// The rich editor mounts asynchronously, so a composer may be asked to focus
// before its editor exists. Only the most recent request is kept: when the
// channel and thread composers both ask during the same page load, the last
// one wins just as it does with the synchronously mounted markdown editor.
let request = null;

export function requestComposerFocus(owner, options) {
  request = { owner, options };
}

export function takeComposerFocusRequest(owner) {
  if (request?.owner !== owner) {
    return null;
  }

  const { options } = request;
  request = null;
  return options;
}
