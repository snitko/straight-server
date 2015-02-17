# require File.expand_path('../../lib/straight-server/initializer', File.dirname(__FILE__))
require 'fileutils'
require_relative '../../lib/straight-server/random_string'
require_relative '../../lib/straight-server/initializer'
require_relative '../../lib/straight-server/config'
require_relative '../../lib/straight-server'

RSpec.describe StraightServer::Initializer do

  before(:each) do
    remove_temp_dir
    templates_dir = File.expand_path('../../templates', File.dirname(__FILE__))
    ENV['HOME']   = File.expand_path('../temp', File.dirname(__FILE__))
    class StraightServer::TestInitializerClass
      include StraightServer::Initializer
      include StraightServer::Initializer::ConfigDir
    end
    @test_class_object = StraightServer::TestInitializerClass.new
    StraightServer::Initializer::ConfigDir.set!
  end

  after(:each) do
    remove_temp_dir
  end

  
  it "creates config files" do

    begin
      @test_class_object.send(:create_config_files)
    rescue Exception => e
      expect(e.status).to eq 0 
    end
    expect(File.exist?(StraightServer::Initializer::ConfigDir.path)).to eq true
    created_config_files = Dir.glob(File.join(File.expand_path('../temp', File.dirname(__FILE__)), '**', '*'), File::FNM_DOTMATCH).select { |f| File.file? f }
    expect(created_config_files.size).to eq 3
    created_config_files.each do |file|
      case file
      when file.match(/.*\.straight\/addons.yml\Z/)
        extect(File.read(file)).to eq File.read(templates_dir + '/addons.yml')
      when file.match(/.*\.straight\/config.yml\Z/)
        extect(File.read(file)).to eq File.read(templates_dir + '/config.yml')
      when file.match(/.*\.straight\/server_secret\Z/)
        extect(File.read(file).size).to eq 16
      end
    end

  end

  it "connects to the database" do

    StraightServer::Config.db = { 
      adapter: 'sqlite',
      name: 'straight.db', 
    }
    begin
      @test_class_object.send(:create_config_files)
    rescue SystemExit => e
    end
    @test_class_object.send(:connect_to_db)
    expect(StraightServer.db_connection.test_connection).to be true

  end

  it "creates logger" do
    # should return Logger class
  end

  it "runs migrations" do
    # expect sec migrator to receive run 
  end

  def remove_temp_dir
    if Dir.exist?(File.expand_path('../temp/', File.dirname(__FILE__)))
      FileUtils.rm_r(File.expand_path('../temp/', File.dirname(__FILE__)))
    end      
  end

end