export let uploadHandlers = [];
export let uploadPreProcessors = [];
export let uploadMarkdownResolvers = [];
export let apiImageWrapperBtnEvents = [];

export function addComposerUploadHandler(extensions, method) {
  uploadHandlers.push({ extensions, method });
}

// Emptied in place, so a component holding the array keeps seeing it.
export function cleanUpComposerUploadHandler() {
  uploadHandlers.length = 0;
}

export function addComposerUploadPreProcessor(pluginClass, optionsResolverFn) {
  uploadPreProcessors.push({ pluginClass, optionsResolverFn });
}

export function cleanUpComposerUploadPreProcessor() {
  uploadPreProcessors = [];
}

export function addComposerUploadMarkdownResolver(resolver) {
  uploadMarkdownResolvers.push(resolver);
}

export function cleanUpComposerUploadMarkdownResolver() {
  uploadMarkdownResolvers = [];
}

export function addApiImageWrapperButtonClickEvent(fn) {
  apiImageWrapperBtnEvents.push(fn);
}
