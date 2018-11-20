module ImportScripts::PhpBB3
  class Constants
    ACTIVE_USER = 0
    INACTIVE_REGISTER = 1 # Newly registered account
    INACTIVE_PROFILE = 2 # Profile details changed
    INACTIVE_MANUAL = 3 # Account deactivated by administrator
    INACTIVE_REMIND = 4 # Forced user account reactivation

    GROUP_ADMINISTRATORS = 'ADMINISTRATORS'
    GROUP_MODERATORS = 'GLOBAL_MODERATORS'

    # https://wiki.phpbb.com/Table.phpbb_users
    USER_TYPE_NORMAL = 0
    USER_TYPE_INACTIVE = 1
    USER_TYPE_IGNORE = 2
    USER_TYPE_FOUNDER = 3

    AVATAR_TYPE_UPLOADED = 1
    AVATAR_TYPE_REMOTE = 2
    AVATAR_TYPE_GALLERY = 3

    AVATAR_TYPE_STRING_UPLOADED = 'avatar.driver.upload'
    AVATAR_TYPE_STRING_REMOTE = 'avatar.driver.remote'
    AVATAR_TYPE_STRING_GALLERY = 'avatar.driver.local'

    FORUM_TYPE_CATEGORY = 0
    FORUM_TYPE_POST = 1
    FORUM_TYPE_LINK = 2

    TOPIC_UNLOCKED = 0
    TOPIC_LOCKED = 1
    TOPIC_MOVED = 2

    POST_NORMAL = 0
    POST_STICKY = 1
    POST_ANNOUNCE = 2
    POST_GLOBAL = 3
  end
end
