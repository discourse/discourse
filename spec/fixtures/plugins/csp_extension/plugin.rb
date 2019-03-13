# name: csp_extension
# about: Fixture plugin that extends default CSP
# version: 1.0
# authors: xrav3nz

extend_content_security_policy(
  script_src: ['https://from-plugin.com'],
  object_src: ['https://test-stripping.com']
)
