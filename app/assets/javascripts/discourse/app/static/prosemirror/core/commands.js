export function buildCommands(extensions, pluginParams, view) {
  const allCommands = {};

  for (const { commands } of extensions) {
    if (commands) {
      for (let [name, command] of Object.entries(commands(pluginParams))) {
        allCommands[name] = (...args) => {
          view.focus();
          return command(...args)(view.state, view.dispatch, view);
        };
      }
    }
  }
  return allCommands;
}

export function buildCustomState(extensions, params) {
  return (viewState) => {
    const allCustomStates = {};

    for (const { state } of extensions) {
      if (state) {
        for (let [name, stateResult] of Object.entries(
          state(params, viewState)
        )) {
          allCustomStates[name] = stateResult;
        }
      }
    }
    return allCustomStates;
  };
}
