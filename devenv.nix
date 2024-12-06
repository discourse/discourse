{ pkgs, ... } : {
  packages = with pkgs; [
    # build dependencies
    openssl
    libyaml

    # image processing
    jhead
    jpegoptim
    oxipng
    pngquant
  ];

  env.DISCOURSE_DEV_ALLOW_ANON_TO_IMPERSONATE = 1;

  languages.ruby.enable = true;
  languages.ruby.version = "3.3";

  languages.javascript.enable = true;
  languages.javascript.pnpm.enable = true;

  services.postgres.enable = true;
  services.postgres.package = pkgs.postgresql_16;

  services.redis.enable = true;
}
