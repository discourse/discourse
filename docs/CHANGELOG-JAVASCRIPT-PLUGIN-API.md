# Changelog

All notable changes to the Discourse JavaScript plugin API located at
app/assets/javascripts/discourse/app/lib/plugin-api.js will be described
in this file..

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2021-12-15
### Added
- Adds `addPosterIcons`, which allows users to add multiple icons to a poster. The
addition of this function also makes the existing `addPosterIcon` now an alias to this
function. Users may now just use `addPosterIcons` for both one or many icons. This
function allows users to now return many icons depending on an `attrs`.

## [1.0.0] - 2021-11-25
### Removed
- Removes the `addComposerUploadProcessor` function, which is no longer used in
favour of `addComposerUploadPreProcessor`. The former was used to add preprocessors
for client side uploads via jQuery file uploader (described at
https://github.com/blueimp/jQuery-File-Upload/wiki/Options#file-processing-options).
The new `addComposerUploadPreProcessor` adds preprocessors for client side
uploads in the form of an Uppy plugin. See https://uppy.io/docs/writing-plugins/
for the Uppy documentation, but other examples of preprocessors in core can be found
in the UppyMediaOptimization and UppyChecksum classes. This has been done because
of the overarching move towards Uppy in the Discourse codebase rather than
jQuery fileupload, which will eventually be removed altogether as a broader effort
to remove jQuery from the codebase.

### Changed
- Changes `addComposerUploadHandler`'s behaviour. Instead of being only usable
for single files at a time, now multiple files are sent to the upload handler
at once. These multiple files are sent based on the groups in which they are
added (e.g. multiple files selected from the system upload dialog, or multiple
files dropped in to the composer). Files will be sent in buckets to the handlers
they match.
