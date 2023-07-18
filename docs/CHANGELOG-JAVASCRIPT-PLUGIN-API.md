# Changelog

All notable changes to the Discourse JavaScript plugin API located at
app/assets/javascripts/discourse/app/lib/plugin-api.js will be described
in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.7.1] - 2023-07-18

### Added

- Adds `addBulkActionButton` which adds actions to the Bulk Topic modal

## [1.7.0] - 2023-07-17

### Added

- Adds `addCommunitySectionLink` which allows plugins to add a navigation link to the Sidebar community section under
  the "More..." links drawer.

- Adds `registerUserCategorySectionLinkCountable` which allows plugins to register a new countable for section links
  under Sidebar Categories section on top of the default countables of unread topics count and new topics count.

- Adds `registerCustomCategorySectionLinkLockIcon` which allows plugins to change the lock icon used for a sidebar
  category section link to indicate that a category is read restricted.

- Adds `registerCustomCategorySectionLinkPrefix` which allows plugins to register a custom prefix for a sidebar category
  section link.

- Adds `registerCustomTagSectionLinkPrefixValue` which allows plugins to register a custom prefix for a sidebar tag
  section link.

- Adds `refreshUserSidebarCategoriesSectionCounts` which allows plugins to trigger a refresh of the counts for all
  category section links under the categories section for a logged in user.

- Adds `addSidebarSection` which allows plugins to add a Sidebar section.

- Adds `registerNotificationTypeRenderer` which allows plugins to register a custom renderer for a notification type
  or override the renderer of an existing type. See lib/notification-types/base.js for documentation and the default
  renderer.

- Adds `registerModelTransformer` which allows plugins to apply transformation using a callback on a list of model
  instances of a specific type. Currently, this API only works on lists rendered in the user menu such as notifications,
  bookmarks and topics (i.e. messages), but it may be extended to other lists in other parts of the app.

- Adds `addUserMessagesNavigationDropdownRow` which allows plugins to add a row to the dropdown used on the
  `userPrivateMessages` route used to navigate between the different user messages pages.

## [1.6.0] - 2022-12-13

### Added

- Adds `addPostSmallActionClassesCallback`, which allows users to register a custom
  function that adds a class to small action posts (pins, closing topics, etc)

## [1.5.0] - 2022-11-21

### Added

- Adds `addComposerSaveErrorCallback`, which allows users to register custom error handling
  for server-side errors when submitting on the composer.

## [1.4.0] - 2022-09-27

### Added

- Adds `registerHighlightJSPlugin`, which allows users to register custom
  HighlightJS plugins. See https://highlightjs.readthedocs.io/en/latest/plugin-api.html
  for documentation.

## [1.3.0] - 2022-05-29

### Added

- N/A - Mistakenly bumped.

## [1.2.0] - 2022-03-18

### Added

- Adds `registerCustomLastUnreadUrlCallback`, which allows users to register a custom
  function that returns a last unread url for a topic list item. When multiple callbacks
  are registered, the first non-null value that is returned will be used.

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
