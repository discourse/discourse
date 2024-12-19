# Changelog

All notable changes to the Discourse JavaScript plugin API located at
app/assets/javascripts/discourse/app/lib/plugin-api.js will be described
in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.39.2] - 2024-12-19

- Removed the deprecation of `includePostAttributes` for now.

## [1.39.1] - 2024-12-18

- Renamed `addTrackedPostProperty` to `addTrackedPostProperties` to allow plugins/TCs to add multiple new tracked properties to the post model.
- Deprecated `includePostAttributes` in favor of `addTrackedPostProperties`.

## [1.39.0] - 2024-11-27

- Added `addTrackedPostProperty` which allows plugins/TCs to add a new tracked property to the post model.

## [1.38.0] - 2024-10-30

- Added `registerMoreTopicsTab` and "more-topics-tabs" value transformer that allows to add or remove new tabs to the "more topics" (suggested/related) area.

## [1.37.3] - 2024-10-24

- Added `disableDefaultKeyboardShortcuts` which allows plugins/TCs to disable default keyboard shortcuts.

## [1.37.2] - 2024-10-02

- Fixed comments and text references to Font Awesome 5 in favor of the more generic Font Awesome due to core now having the latest version and no longer needing to specify version 5.

## [1.37.1] - 2024-08-21

- Added support for `shortcut` in `addComposerToolbarPopupMenuOption` which allows to add a keyboard shortcut to the popup menu option.

## [1.37.0] - 2024-08-19

- Added `addAboutPageActivity` which allows plugins/TCs to register a custom site activity item in the new /about page. Requires the server-side `register_stat` plugin API.

## [1.36.0] - 2024-08-06

- Added `addLogSearchLinkClickedCallbacks` which allows plugins/TCs to register a callback when a search link is clicked and before a search log is created

## [1.35.0] - 2024-07-30

- Added `registerBehaviorTransformer` which allows registering a transformer callback to override behavior defined in Discourse modules
- Added `addBehaviorTransformerName` which allows plugins/TCs to register a new transformer to override behavior defined in their modules

## [1.34.0] - 2024-06-06

- Added `registerValueTransformer` which allows registering a transformer callback to override values defined in Discourse modules
- Added `addValueTransformerName` which allows plugins/TCs to register a new transformer to override values defined in their modules

## [1.33.0] - 2024-06-06

- Added `addCustomUserFieldValidationCallback` which allows to set a callback to change the validation and user facing message when attempting to save the signup form.

## [1.32.0] - 2024-05-16

- Added `registerHomeLogoHrefCallback` which allows to set a callback to change the home logo URL.

## [1.31.0] - 2024-04-22

- Added `addTopicAdminMenuButton` which allows to register a new button in the topic admin menu.

## [1.30.0] - 2024-03-20

- Added `addAdminPluginConfigurationNav`, which defines a list of links used in the adminPlugins.show page for a specific plugin, and displays them either in an inner sidebar or in a top horizontal nav.

## [1.29.0] - 2024-03-05

- Added `headerButtons` which allows for manipulation of the header buttons. This includes, adding, removing, or modifying the order of buttons.

## [1.28.0] - 2024-02-21

- Added `headerIcons` which allows for manipulation of the header icons. This includes, adding, removing, or modifying the order of icons.

## [1.27.0] - 2024-02-21

- Deprecated `addToHeaderIcons` in favor of `headerIcons`

## [1.26.0] - 2024-02-21

- Added `renderBeforeWrapperOutlet` which is used for rendering components before the content of wrapper plugin outlets
- Added `renderAfterWrapperOutlet` which is used for rendering components after the content of wrapper plugin outlets

## [1.25.0] - 2024-02-05

- Added `addComposerImageWrapperButton` which is used to add a custom button to the composer preview's image wrapper that appears on hover of an uploaded image.

## [1.24.0] - 2024-01-08

- Added `addAdminSidebarSectionLink` which is used to add a link to a specific admin sidebar section, as a replacement for the `admin-menu` plugin outlet. This only has an effect if the `admin_sidebar_enabled_groups` site setting is in use, which enables the new admin nav sidebar.

## [1.23.0] - 2024-01-03

### Added

- Added `setUserMenuNotificationsLimit` function which is used to specify a new limit for the notifications query when the user menu is opened.

## [1.21.0] - 2023-12-22

### Added

- Added `includeUserFieldPropertiesOnSave` function, which includes the passed user field properties in the user field save request. This is useful for plugins that are adding additional columns to the user field model and want to save the new property values alongside the default user field properties (all under the same save call).


## [1.20.0] - 2023-12-20

### Added

- Added `addSearchMenuAssistantSelectCallback` function, which is used to override the behavior of clicking a search menu assistant item. If any callback returns false, the core behavior will not be executed.

## [1.19.0] - 2023-12-13

### Added

- Added `setNotificationsLimit` function, which sets a new limit for how many notifications are loaded for the user notifications route

- Added `addBeforeLoadMoreNotificationsCallback` function, which takes a function as the argument. All added callbacks are evaluated before `loadMore` is triggered for user notifications. If any callback returns false, notifications will not be loaded.

## [1.18.0] - 2023-12-1

### Added

- Added `setDesktopTopicTimelineScrollAreaHeight` function, which takes an object with min/max key value pairs as an argument. This is used to adjust the height of the topic timeline on desktop without CSS hacks that break the functionality of the topic timeline.

## [1.17.0] - 2023-11-30

### Added

- Introduces `forceDropdownAnimationForMenuPanels` API for forcing one or many Menu Panels (search-menu, user-menu, etc) to be rendered as a dropdown. This can be useful for plugins as the default behavior is to add a 'slide-in' behavior to a menu panel if you are viewing on a small screen. eg. mobile.

## [1.16.0] - 2023-11-17

### Added

- Added `recurrenceRule` option to `downloadCalendar`, this can be used to set recurring events in the calendar. Rule syntax can be found at https://datatracker.ietf.org/doc/html/rfc5545#section-3.3.10.

## [1.15.0] - 2023-10-18

### Added

- Added `hidden` option to `addSidebarPanel`, this can be used to remove the panel from combined sidebar mode as well as hiding its switch button. Useful for cases where only one sidebar should be shown at a time regardless of other panels.
- Added `getSidebarPanel` function, which returns the current sidebar panel object for comparison.

## [1.14.0] - 2023-10-06

### Added

- Added `addComposerToolbarPopupMenuOption` as a replacement for `addToolbarPopupMenuOptionsCallback` with new changes
  introduced to the method's signature.

### Changed

- Deprecate `addToolbarPopupMenuOptionsCallback` in favor of `addComposerToolbarPopupMenuOption`.

## [1.13.0] - 2023-10-05

### Added

- Introduces `renderInOutlet` API for rendering components into plugin outlets

## [1.12.0] - 2023-09-06

### Added

- Adds `addPostAdminMenuButton` which allows to register a new button in the post admin menu.

## [1.11.0] - 2023-08-30

### Added

- Adds `addBeforeAuthCompleteCallback` which allows plugins and themes to add functions to be
  evaluated before the auth-complete logic is run. If any of these callbacks return false, the
  auth-complete logic will be aborted.

## [1.10.0] - 2023-08-25

### Added

- Adds `registerReviewableActionModal` which allows core and plugins to register a modal component class
  which is used to show a modal for certain reviewable actions.

## [1.9.0] - 2023-08-09

### Added

- Adds `showSidebarSwitchPanelButtons` which is experimental, and allows plugins to show sidebar switch panel buttons in separated mode

- Adds `hideSidebarSwitchPanelButtons` which is experimental, and allows plugins to hide sidebar switch panel buttons in separated mode

## [1.8.1] - 2023-08-08

### Added

- Adds `replacePostMenuButton` which allows plugins to replace a post menu button with a widget.

## [1.8.0] - 2023-07-18

### Added
- Adds `addSidebarPanel` which is experimental, and adds a Sidebar panel by returning a class which extends from the
  BaseCustomSidebarPanel class.

- Adds `setSidebarPanel` which is experimental, and sets the current sidebar panel.

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
