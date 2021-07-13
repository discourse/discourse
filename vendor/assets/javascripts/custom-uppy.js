// We need a custom build of Uppy because we do not use webpack for
// our JS modules/build. The only way to get what you want from Uppy
// is to use the webpack modules or to include the entire Uppy project
// including all plugins in a single JS file. This way we can just
// use the plugins we actually want.
window.Uppy = {}
Uppy.Core = require('@uppy/core')
Uppy.Plugin = Uppy.Core.Plugin
Uppy.XHRUpload = require('@uppy/xhr-upload')
Uppy.AwsS3 = require('@uppy/aws-s3')
Uppy.AwsS3Multipart = require('@uppy/aws-s3-multipart')
Uppy.DropTarget = require('@uppy/drop-target')
