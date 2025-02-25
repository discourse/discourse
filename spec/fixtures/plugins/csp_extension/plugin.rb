# frozen_string_literal: true

# name: csp_extension
# about: Fixture plugin that extends default CSP
# version: 1.0
# authors: xrav3nz

extend_content_security_policy(
  script_src: [
    "https://from-plugin.com",
    "/local/path",
    "'unsafe-eval' https://invalid.example.com",
  ],
  object_src: ["https://test-stripping.com"],
  frame_ancestors: ["https://frame-ancestors-plugin.ext"],
  manifest_src: ["https://manifest-src.com"],
)
