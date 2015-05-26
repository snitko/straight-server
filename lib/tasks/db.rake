require_relative '../straight-server'

namespace :db do
  task :environment do
    include StraightServer::Initializer
    ConfigDir.set!
    create_config_files
    read_config_file
    connect_to_db
  end

  desc "Migrate the database"
  task :migrate, [:step] => :environment do |t, args|
    target = args[:step] && (step = args[:step].to_i) > 0 ?
               current_migration_version + step : nil

    Sequel::Migrator.run(StraightServer.db_connection, MIGRATIONS_ROOT, target: target)
  end

  desc "Rollbacks the database migrations"
  task :rollback, [:step] => :environment do |t, args|
    target = args[:step] && (step = args[:step].to_i) > 0 ?
      current_migration_version - step : 0

    Sequel::Migrator.run(StraightServer.db_connection, MIGRATIONS_ROOT, target: target)
  end

  def current_migration_version
    db = StraightServer.db_connection

    Sequel::Migrator.migrator_class(MIGRATIONS_ROOT).new(db, MIGRATIONS_ROOT, {}).current
  end
end
