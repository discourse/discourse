{
  description = "Discourse development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          name = "discourse-dev";

          # Required packages
          buildInputs = with pkgs; [
            git
            ruby
            postgresql
            redis
            nodejs
            yarn
            gcc
            gnumake
            libxml2
            libxslt
            zlib
            imagemagick
          ];

          # Environment variables
          shellHook = ''
            export PGHOST=localhost
            export PGUSER=discourse
            export PGDATABASE=discourse_development

            # Start PostgreSQL and Redis
            if ! pgrep -x "postgres" > /dev/null; then
              echo "Starting PostgreSQL..."
              mkdir -p $PWD/postgres-data
              initdb -D $PWD/postgres-data
              pg_ctl -D $PWD/postgres-data -l $PWD/postgres.log start
            fi

            if ! pgrep -x "redis-server" > /dev/null; then
              echo "Starting Redis..."
              redis-server --daemonize yes
            fi

            # Create the database and user if they don't exist
            if ! psql -lqt | cut -d \| -f 1 | grep -qw $PGDATABASE; then
              echo "Creating database $PGDATABASE..."
              createdb $PGDATABASE
            fi

            if ! psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$PGUSER'" | grep -q 1; then
              echo "Creating user $PGUSER..."
              createuser $PGUSER
            fi

            echo "Discourse development environment is ready!"
          '';
        };
      }
    );
}
