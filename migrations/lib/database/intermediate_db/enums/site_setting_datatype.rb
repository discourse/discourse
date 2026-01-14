# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB::Enums
  module SiteSettingDatatype
    extend ::Migrations::Enum

    STRING = 1
    TIME = 2
    INTEGER = 3
    FLOAT = 4
    BOOL = 5
    NULL = 6
    ENUM = 7
    LIST = 8
    URL_LIST = 9
    HOST_LIST = 10
    CATEGORY_LIST = 11
    VALUE_LIST = 12
    REGEX = 13
    EMAIL = 14
    USERNAME = 15
    CATEGORY = 16
    UPLOADED_IMAGE_LIST = 17
    UPLOAD = 18
    GROUP = 19
    GROUP_LIST = 20
    TAG_LIST = 21
    COLOR = 22
    SIMPLE_LIST = 23
    EMOJI_LIST = 24
    HTML_DEPRECATED = 25
    TAG_GROUP_LIST = 26
    FILE_SIZE_RESTRICTION = 27
    OBJECTS = 28
    LOCALE_ENUM = 29
  end
end
