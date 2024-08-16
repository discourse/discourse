let decorators = [];

export function registerMentionsDecorator(decorator) {
  decorators.push(decorator);
}

export function resetAdminPluginConfigNav() {
  decorators.length = 0;
}

export function mentionsDecorators() {
  return decorators;
}
